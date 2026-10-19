package com.hiddify.hiddify.bg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import com.hiddify.hiddify.NetworkKinds
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import com.hiddify.hiddify.Application
import com.hiddify.hiddify.R
import com.hiddify.hiddify.Settings
import com.hiddify.hiddify.constant.Action
import com.hiddify.hiddify.constant.Alert
import com.hiddify.hiddify.constant.Status
import com.hiddify.core.mobile.SetupOptions

import go.Seq
import com.hiddify.core.libbox.Libbox
import com.hiddify.core.mobile.Mobile


import com.hiddify.core.libbox.CommandServer
import com.hiddify.core.libbox.CommandServerHandler
import com.hiddify.core.libbox.Notification
import com.hiddify.core.libbox.PlatformInterface
import com.hiddify.core.libbox.SystemProxyStatus
import com.hiddify.hiddify.BuildConfig
import com.hiddify.hiddify.MainActivity
import com.hiddify.hiddify.constant.Bugs
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.isActive
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.channels.Channel
import java.io.File
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class BoxService(
        private val service: Service,
        private val platformInterface: PlatformInterface
)  {

    companion object {
        private const val TAG = "A/BoxService"

        private var initializeOnce = false
        private lateinit var workingDir: File
        private fun initialize() {
            System.setProperty("GODEBUG", "efence=1,stacktraceback=2");
            System.setProperty("GOGC", "off");
            if (initializeOnce) return
            val baseDir = Application.application.filesDir

            baseDir.mkdirs()
            workingDir = Application.application.getExternalFilesDir(null) ?: return
            workingDir.mkdirs()
            val tempDir = Application.application.cacheDir
            tempDir.mkdirs()
            Log.d(TAG, "base dir: ${baseDir.path}")
            Log.d(TAG, "working dir: ${workingDir.path}")
            Log.d(TAG, "temp dir: ${tempDir.path}")

//
            //Mobile.setup(baseDir.path, workingDir.path, tempDir.path,  2L ,"127.0.0.1:{Setting}","",false,this)
//            Libbox.setup(baseDir.path, workingDir.path, tempDir.path, false)

//            Libbox.setup(SetupOptions().also {
//                it.basePath = baseDir.path
//                it.workingPath = workingDir.path
//                it.tempPath = tempDir.path
//                it.fixAndroidStack = Bugs.fixAndroidStack
//
//            })
            Libbox.redirectStderr(File(Settings.workingDir, "stderr.log").path)
            initializeOnce = true
            return
        }

        fun start() {
            val intent = runBlocking {
                withContext(Dispatchers.IO) {
                    Intent(Application.application, Settings.serviceClass())
                }
            }
            ContextCompat.startForegroundService(Application.application, intent)
        }

        fun stop() {
            Application.application.sendBroadcast(
                    Intent(Action.SERVICE_CLOSE).setPackage(
                            Application.application.packageName
                    )
            )
        }


    }

    var fileDescriptor: ParcelFileDescriptor? = null

    private val status = MutableLiveData(Status.Stopped)
    private val binder = ServiceBinder(status)
    private val notification = ServiceNotification(status, service)
//    private var boxService: BoxService? = null
    private var commandServer: CommandServer? = null
    private var receiverRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Action.SERVICE_CLOSE -> {
                    stopService()
                }

                PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        serviceUpdateIdleMode()
                    }
                }

                Intent.ACTION_SCREEN_ON, Intent.ACTION_SCREEN_OFF -> screenWake.trySend(Unit)
            }
        }
    }
    


    private var activeProfileName = ""

    // A-VPN auto-pause: while an app from the list is on screen the tunnel is closed (the VPN disappears for
    // every app) but this service stays up with a "paused" notification, and opens the tunnel again when the app
    // leaves the screen. Staying up matters: Android doesn't let a stopped VPN restart itself from the background.
    @Volatile
    private var paused = false
    /** paused for a home Wi-Fi, not for an app on screen: only leaving home ends it */
    @Volatile private var pausedForHome = false
    private var lastHomeCheck = 0L
    private val lifecycle = Mutex()
    private val generation = AtomicLong()
    @Volatile private var stopping = false
    private var autoPauseJob: Job? = null
    private val screenWake = Channel<Unit>(Channel.CONFLATED)

    @OptIn(DelicateCoroutinesApi::class)
    private fun startAutoPause() {
        autoPauseJob?.cancel()
        ForegroundApp.reset()
        // Runs for the whole session so auto-pause settings can change without reconnecting. UsageStats is
        // sampled less often when auto-pause is off, and much less often when screen time cannot be observed.
        autoPauseJob = GlobalScope.launch(Dispatchers.IO) {
            while (isActive) {
                val screenInteractive = Application.powerManager.isInteractive
                val apps = Settings.autoPauseApps
                val autoPauseActive = Settings.autoPauseEnabled && apps.isNotEmpty()
                val interval = ForegroundSampling.intervalMillis(
                    autoPauseActive,
                    screenInteractive && ForegroundApp.hasPermission(service),
                    screenInteractive,
                )
                if (screenInteractive) delay(interval) else withTimeoutOrNull(interval) { screenWake.receive() }
                // a home Wi-Fi looked at every 15 seconds at most (besides every network change)
                val now = android.os.SystemClock.elapsedRealtime()
                if ((Settings.homeWifiEnabled || pausedForHome) && now - lastHomeCheck >= 15_000) {
                    lastHomeCheck = now
                    checkHome()
                }
                // at home the apps on screen change nothing
                if (pausedForHome) continue
                val canObserve = Application.powerManager.isInteractive && ForegroundApp.hasPermission(service)
                if (!canObserve) {
                    ForegroundApp.observeScreen(service, null, android.os.SystemClock.elapsedRealtime())
                    if (paused && !pausedForHome) resume()
                    continue
                }
                val app = runCatching { ForegroundApp.current(service) }.getOrNull()
                ForegroundApp.observeScreen(service, app, android.os.SystemClock.elapsedRealtime())
                if (app == null) continue
                if (!autoPauseActive) { if (paused && !pausedForHome) resume(); continue }
                if (!paused && app in apps && status.value == Status.Started) {
                    pause(app)
                } else if (paused && app !in apps) {
                    resume()
                }
            }
        }
    }

    // A-VPN: the servers follow the phone's network with the app closed too. The app leaves a config for Wi-Fi
    // and one for mobile data ("LTE Only" servers on mobile, the others on Wi-Fi); when the network under the VPN
    // changes this reloads the core on the other one. It waited for the app to be opened before, the VPN up but
    // its servers dead on the new network.
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var networkCheck: Job? = null

    private fun watchNetwork() {
        // also after a pause or a reload: the network may have changed meanwhile
        scheduleNetworkCheck()
        if (networkCallback != null) return
        val cm = service.getSystemService(ConnectivityManager::class.java) ?: return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = scheduleNetworkCheck()
            override fun onLost(network: Network) = scheduleNetworkCheck()
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = scheduleNetworkCheck()
        }
        // the physical networks only (a request leaves VPNs out unless asked)
        val request = NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build()
        runCatching { cm.registerNetworkCallback(request, callback) }
            .onSuccess { networkCallback = callback }
            .onFailure { Log.w(TAG, "network watch failed: ${it.message}") }
    }

    private fun unwatchNetwork() {
        networkCheck?.cancel()
        networkCheck = null
        val callback = networkCallback ?: return
        networkCallback = null
        runCatching { service.getSystemService(ConnectivityManager::class.java)?.unregisterNetworkCallback(callback) }
    }

    @OptIn(DelicateCoroutinesApi::class)
    private fun scheduleNetworkCheck() {
        networkCheck?.cancel()
        // a new network takes a moment to come up and be validated (Wi-Fi's "validated" decides it)
        networkCheck = GlobalScope.launch(Dispatchers.IO) {
            val operation = generation.get()
            delay(4_000)
            if (Settings.homeWifiEnabled || pausedForHome) {
                lastHomeCheck = android.os.SystemClock.elapsedRealtime()
                checkHome()
            }
            lifecycle.withLock { if (operation == generation.get() && !stopping) switchToNetwork(operation) }
        }
    }

    private suspend fun switchToNetwork(operation: Long) {
        if (status.value != Status.Started || paused || fileDescriptor == null) return
        val network = NetworkKinds.underlying(service)
        val applied = Settings.appliedNetwork
        if (network == "unknown" || network == applied) return
        val path = Settings.networkConfig(network)
        if (path.isBlank() || !File(path).exists()) return
        Log.i(TAG, "network is now $network, was $applied: reloading its servers")
        try {
            try {
                Mobile.reload(path, "")
                Log.i(TAG, "network $network applied without restarting the tunnel")
            } catch (e: Exception) {
                Log.w(TAG, "network reload needs a restart: ${e.message}")
                if (operation != generation.get() || stopping) return
                // Release Android's copy too, as in serviceReload0: the core owns a duplicate.
                fileDescriptor?.close()
                fileDescriptor = null
                Mobile.rebuild(path, "")
            }
            if (operation != generation.get() || stopping) return
            Settings.appliedNetwork = network
        } catch (e: Exception) {
            Log.w(TAG, "restart for the $network network failed: ${e.message}")
            // back on the config it had rather than no VPN at all
            if (operation != generation.get() || stopping) return
            runCatching {
                fileDescriptor?.close()
                fileDescriptor = null
                Mobile.rebuild(Settings.networkConfig(applied), "")
            }.onFailure {
                Log.e(TAG, "network rollback failed: ${it.message}")
                terminateFailedSession(it.message)
            }
        }
    }

    /** The VPN on a home Wi-Fi pauses (the router runs one of its own) and comes back off it. */
    private suspend fun checkHome() {
        val home = Settings.homeWifiEnabled && runCatching { HomeWifi.atHome(service) }.getOrDefault(false)
        if (home && !paused && status.value == Status.Started) {
            Log.i(TAG, "home Wi-Fi: pausing the VPN")
            pause(null)
        } else if (!home && paused && pausedForHome) {
            Log.i(TAG, "off the home Wi-Fi: the VPN comes back")
            resume()
        }
    }

    /** [app]: paused while it is on screen; null: paused for a home Wi-Fi. */
    private suspend fun pause(app: String?) = lifecycle.withLock {
        if (stopping || status.value != Status.Started) return@withLock
        paused = true
        pausedForHome = app == null
        val label = if (app == null) "" else runCatching {
            val pm = service.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(app, 0)).toString()
        }.getOrDefault(app)
        try {
            fileDescriptor?.close()
            fileDescriptor = null
            Mobile.suspend()
            DefaultNetworkMonitor.stop()
            if (stopping) return@withLock
            withContext(Dispatchers.Main) {
                if (stopping) return@withContext
                notification.showText(
                    "A-VPN — пауза",
                    if (app == null) "Домашний Wi-Fi: VPN уже на роутере. VPN включится, когда вы уйдёте из этой сети"
                    else "Открыто: $label. VPN включится, когда вы из него выйдете",
                )
                status.value = Status.Stopped
            }
        } catch (e: Exception) { terminateFailedSession(e.message) }
    }

    /** Resume the retained daemon; only manual stop ends its logical session. */
    private suspend fun resume() = lifecycle.withLock {
        if (stopping || !paused) return@withLock
        val operation = generation.get()
        try {
            DefaultNetworkMonitor.start()
            Mobile.rebuild("", "")
            if (operation != generation.get() || stopping) return@withLock
            paused = false
            pausedForHome = false
            withContext(Dispatchers.Main) {
                if (operation != generation.get() || stopping) return@withContext
                status.value = Status.Started
                notification.show(activeProfileName, R.string.status_started)
            }
            if (operation != generation.get() || stopping) return@withLock
            watchNetwork()
        } catch (e: Exception) { terminateFailedSession(e.message) }
    }

    private suspend fun terminateFailedSession(message: String?) = withContext(NonCancellable) {
        generation.incrementAndGet()
        stopping = true
        autoPauseJob?.cancel()
        unwatchNetwork()
        paused = false
        pausedForHome = false
        runCatching { fileDescriptor?.close() }
        fileDescriptor = null
        DefaultNetworkMonitor.stop()
        runCatching { Mobile.close(4L) }
        stopAndAlert(Alert.StartService, message)
        service.stopSelf()
    }

    private suspend fun startService() = lifecycle.withLock {
        if (!stopping) startServiceLocked()
    }

    private suspend fun startServiceLocked() {
        val operation = generation.get()
        try {
            status.postValue(Status.Starting)
            Log.d(TAG, "starting service")
            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
            }

            val selectedConfigPath = Settings.activeConfigPath
            if (selectedConfigPath.isBlank()) {
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            activeProfileName = Settings.activeProfileName

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
                binder.broadcast {
                    it.onServiceResetLogs(listOf())
                }
            }

            DefaultNetworkMonitor.start()
            Libbox.setMemoryLimit(!Settings.disableMemoryLimit)
            val setupOptions = SetupOptions().also {
                it.basePath = Settings.baseDir
                it.workingDir = Settings.workingDir
                it.tempDir = Settings.tempDir
                it.fixAndroidStack = com.hiddify.hiddify.bg.Bugs.fixAndroidStack
                it.mode = 4L//mode.toLong()
                it.listen = "127.0.0.1:${Settings.grpcServiceModePort}"
                it.secret = Settings.grpcSecret
                it.debug = Settings.debugMode
            }
            val newService = try {
                try {
                    Mobile.setup(setupOptions, platformInterface)
                } catch (e: Exception) {
                    // A-VPN: a core left half-open (by a reload, or an older auto-pause) refuses to set up again;
                    // close it and try once more instead of failing every start until the app is killed
                    Log.w(TAG, "core setup failed, closing it and retrying: ${e.message}")
                    runCatching { Mobile.close(4L) }
                    Mobile.setup(setupOptions, platformInterface)
                }


//                Libbox.newService(content,platformInterface)

            } catch (e: Exception) {
                stopAndAlert(Alert.CreateService, e.message)
                return
            }
            if (operation != generation.get() || stopping) return

            if (Settings.startCoreAfterStartingService){
                Mobile.start("","")
                }
            if (operation != generation.get() || stopping) return
            status.postValue(Status.Started)
//            if (delayStart) {
//                delay(1000L)
//            }

//            newService.start()
//            boxService = newService
//            commandServer?.setService(boxService)


            withContext(Dispatchers.Main) {
                if (operation != generation.get() || stopping) return@withContext
                notification.show(activeProfileName, R.string.status_started)
            }
            if (operation != generation.get() || stopping) return
            notification.start()
            startAutoPause()
            watchNetwork()
        } catch (e: Exception) {
            stopAndAlert(Alert.StartService, e.message)
            return
        }
    }

    fun serviceReload() {
        runBlocking {
            serviceReload0()
        }
    }

    suspend fun serviceReload0() = lifecycle.withLock {
        if (stopping) return@withLock
        notification.close()
        status.postValue(Status.Starting)

        val pfd = fileDescriptor
        if (pfd != null) {
            pfd.close()
            fileDescriptor = null
        }
        
//        boxService?.apply {
//            runCatching {
//                close()
//            }.onFailure {
//                writeLog("service: error when closing: $it")
//            }
//            Seq.destroyRef(refnum)
//        }
        Mobile.stop()
//        boxService = null
        
            if (!stopping) startServiceLocked()
        
    }

    fun getSystemProxyStatus(): SystemProxyStatus {
        val status = SystemProxyStatus()
        if (service is VPNService) {
            status.available = service.systemProxyAvailable
            status.enabled = service.systemProxyEnabled
        }
        return status
    }

    fun setSystemProxyEnabled(isEnabled: Boolean) {
        serviceReload()
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun serviceUpdateIdleMode() {
        if (Application.powerManager.isDeviceIdleMode) {
//            boxService?.pause()
            //Mobile.pause()
        } else {
            Mobile.wake()
//            boxService?.wake()
        }
    }

    private fun stopService() {
        // a paused VPN is stopped too: the service is still up and has to go
        if (status.value == Status.Stopped && !paused) return
        generation.incrementAndGet()
        stopping = true
        autoPauseJob?.cancel()
        autoPauseJob = null
        unwatchNetwork()
        paused = false
        pausedForHome = false
        status.value = Status.Stopping
        if (receiverRegistered) {
            service.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        notification.close()
        GlobalScope.launch(Dispatchers.IO) {
          lifecycle.withLock {
            val pfd = fileDescriptor
            if (pfd != null) {
                pfd.close()
                fileDescriptor = null
            }
//            commandServer?.setService(null)
//            boxService?.apply {
//                runCatching {
//                    close()
//                }.onFailure {
//                    writeLog("service: error when closing: $it")
//                }
//                //Seq.destroyRef(refnum)
//            }

//            boxService = null
//            Libbox.registerLocalDNSTransport(null)
            DefaultNetworkMonitor.stop()

//            commandServer?.apply {
//                close()
//                Seq.destroyRef(refnum)
//            }
//            commandServer = null
            Settings.startedByUser = false
            withContext(Dispatchers.Main) {
                Mobile.close(4L)
                status.value = Status.Stopped
                service.stopSelf()
            }
            notification.close()
          }
        }
    }

    private suspend fun stopAndAlert(type: Alert, message: String? = null) {
        Settings.startedByUser = false
        withContext(Dispatchers.Main) {
            if (receiverRegistered) {
                service.unregisterReceiver(receiver)
                receiverRegistered = false
            }
            notification.close()
            binder.broadcast { callback ->
                callback.onServiceAlert(type.ordinal, message)
            }
            status.value = Status.Stopped
        }
    }

    @OptIn(DelicateCoroutinesApi::class)
    @Suppress("SameReturnValue")
    internal fun onStartCommand(): Int {
        if (status.value != Status.Stopped) return Service.START_NOT_STICKY
        if (paused) {
            // the user turned it on by hand while paused: reconnect now, the watch goes on
            GlobalScope.launch(Dispatchers.IO) { resume() }
            return Service.START_NOT_STICKY
        }
        stopping = false
        status.value = Status.Starting

        if (!receiverRegistered) {
            ContextCompat.registerReceiver(service, receiver, IntentFilter().apply {
                addAction(Action.SERVICE_CLOSE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
                }
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            }, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }

        GlobalScope.launch(Dispatchers.IO) {
            Settings.startedByUser = true
            initialize()
//            try {
//                startCommandServer()
//            } catch (e: Exception) {
//                stopAndAlert(Alert.StartCommandServer, e.message)
//                return@launch
//            }
            startService()
        }
        return Service.START_NOT_STICKY
    }

    fun onBind(intent: Intent): IBinder {
        return binder
    }

    fun onDestroy() {
        binder.close()
    }

    fun onRevoke() {
        stopService()
    }

    internal fun sendNotification(notification: Notification) {
        return
        val builder =
            NotificationCompat.Builder(service, notification.identifier).setShowWhen(false)
                .setContentTitle(notification.title).setContentText(notification.body)
                .setOnlyAlertOnce(true).setSmallIcon(R.drawable.ic_stat_logo)
                .setCategory(NotificationCompat.CATEGORY_EVENT)
                .setPriority(NotificationCompat.PRIORITY_HIGH).setAutoCancel(true)
        if (!notification.subtitle.isNullOrBlank()) {
            builder.setContentInfo(notification.subtitle)
        }
        if (!notification.openURL.isNullOrBlank()) {
            builder.setContentIntent(
                PendingIntent.getActivity(
                    service,
                    0,
                    Intent(
                        service,
                        MainActivity::class.java,
                    ).apply {
                        setAction(Action.SERVICE).setData(Uri.parse(notification.openURL))
                        setFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    },
                    ServiceNotification.flags,
                ),
            )
        }
        GlobalScope.launch(Dispatchers.Main) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Application.notification.createNotificationChannel(
                    NotificationChannel(
                        notification.identifier,
                        notification.typeName,
                        NotificationManager.IMPORTANCE_HIGH,
                    ),
                )
            }
            Application.notification.notify(notification.identifier, notification.typeID, builder.build())
        }
    }

    internal fun cancelNotification(identifier: String, typeID: Int) {
        GlobalScope.launch(Dispatchers.Main) {
            Application.notification.cancel(identifier, typeID)
        }
    }

     fun writeDebugMessage(message: String?) {
        Log.d("BoxService", message!!)
        binder.broadcast {
            it.onServiceWriteLog(message)
        }
    }

}
