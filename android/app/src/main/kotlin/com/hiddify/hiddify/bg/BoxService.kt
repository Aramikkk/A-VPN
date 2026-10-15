package com.hiddify.hiddify.bg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
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
import kotlinx.coroutines.isActive
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.io.File

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
            }
        }
    }
    


    private var activeProfileName = ""

    // A-VPN auto-pause: while an app from the list is on screen the tunnel is closed (the VPN disappears for
    // every app) but this service stays up with a "paused" notification, and opens the tunnel again when the app
    // leaves the screen. Staying up matters: Android doesn't let a stopped VPN restart itself from the background.
    @Volatile
    private var paused = false
    private var autoPauseJob: Job? = null

    @OptIn(DelicateCoroutinesApi::class)
    private fun startAutoPause() {
        autoPauseJob?.cancel()
        ForegroundApp.reset()
        // runs for the whole session and reads the settings each time, so turning auto-pause on or off, or
        // changing the list, works without reconnecting; while it's off it only reads two preferences a second
        autoPauseJob = GlobalScope.launch(Dispatchers.IO) {
            while (isActive) {
                delay(1_000)
                // off: the settings looked at every 5 seconds; the screen off: nothing is on it, nothing to check
                val apps = Settings.autoPauseApps
                if (!Settings.autoPauseEnabled || apps.isEmpty() || !ForegroundApp.hasPermission(service)) {
                    if (paused) resume()
                    delay(4_000)
                    continue
                }
                if (!Application.powerManager.isInteractive) {
                    delay(4_000)
                    continue
                }
                val app = runCatching { ForegroundApp.current(service) }.getOrNull() ?: continue
                if (!paused && app in apps && status.value == Status.Started) {
                    pause(app)
                } else if (paused && app !in apps) {
                    resume()
                }
            }
        }
    }

    private suspend fun pause(app: String) {
        Log.d(TAG, "auto-pause for $app")
        paused = true
        val label = runCatching {
            val pm = service.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(app, 0)).toString()
        }.getOrDefault(app)
        withContext(Dispatchers.Main) {
            notification.showText("A-VPN — пауза", "Открыто: $label. VPN включится, когда вы из него выйдете")
        }
        val pfd = fileDescriptor
        if (pfd != null) {
            pfd.close()
            fileDescriptor = null
        }
        // a full close, as when the VPN is turned off: a core that is only stopped can't be set up again
        // ("createService - null" on every later start)
        DefaultNetworkMonitor.stop()
        withContext(Dispatchers.Main) {
            runCatching { Mobile.close(4L) }
        }
        status.postValue(Status.Stopped)
    }

    /** [startCore]: start the core with its last configuration (as on boot); false when the app starts it. */
    private suspend fun resume(startCore: Boolean = true) {
        Log.d(TAG, "auto-pause over, reconnecting")
        paused = false
        if (startCore) Settings.startCoreAfterStartingService = true
        startService()
    }

    private suspend fun startService() {
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
                it.secret = ""
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
            status.postValue(Status.Started)

            if (Settings.startCoreAfterStartingService){
                Mobile.start("","")
                }
//            if (delayStart) {
//                delay(1000L)
//            }

//            newService.start()
//            boxService = newService
//            commandServer?.setService(boxService)


            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_started)
            }
            notification.start()
            startAutoPause()
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

    suspend fun serviceReload0() {
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
        
            startService()
        
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
        autoPauseJob?.cancel()
        autoPauseJob = null
        paused = false
        status.value = Status.Stopping
        if (receiverRegistered) {
            service.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        notification.close()
        GlobalScope.launch(Dispatchers.IO) {
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
            paused = false
            GlobalScope.launch(Dispatchers.IO) { resume(startCore = Settings.startCoreAfterStartingService) }
            return Service.START_NOT_STICKY
        }
        status.value = Status.Starting

        if (!receiverRegistered) {
            ContextCompat.registerReceiver(service, receiver, IntentFilter().apply {
                addAction(Action.SERVICE_CLOSE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
                }
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