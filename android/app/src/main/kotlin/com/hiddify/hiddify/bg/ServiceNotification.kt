package com.hiddify.hiddify.bg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.annotation.StringRes
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.lifecycle.MutableLiveData
import com.hiddify.core.api.v2.config.Protocol
import com.hiddify.core.api.v2.hcommon.Empty
import com.hiddify.core.api.v2.hcore.CoreClient
import com.hiddify.core.api.v2.hcore.SystemInfo
import com.hiddify.core.api.v2.hello.HelloClient
import com.hiddify.core.api.v2.hello.HelloRequest
import com.hiddify.hiddify.Application
import com.hiddify.hiddify.MainActivity
import com.hiddify.hiddify.R
import com.hiddify.hiddify.Settings
import com.hiddify.hiddify.constant.Action
import com.hiddify.hiddify.constant.Status
//import com.hiddify.hiddify.utils.CommandClient
import com.hiddify.core.libbox.Libbox
import com.hiddify.hiddify.Application.Companion.notification
import com.hiddify.hiddify.utils.GrpcClientProvider
import com.squareup.wire.GrpcClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.isActive

import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.ReceiveChannel
import kotlinx.coroutines.channels.SendChannel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import java.io.IOException
import kotlinx.coroutines.delay
import kotlinx.coroutines.CancellationException
class ServiceNotification(private val status: MutableLiveData<Status>, private val service: Service) : BroadcastReceiver(){
    companion object {
        private const val notificationId = 1
        // a channel keeps the settings it was created with, so the badge-less one needs a new id
        private const val notificationChannel = "service_no_badge"
        private const val oldNotificationChannel = "service"
        var coreClient: CoreClient?=null
        val flags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        fun checkPermission(): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                return true
            }
            return Application.notification.areNotificationsEnabled()
        }
    }
    val streamingCoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())


//
//    private val commandClient =
//            CommandClient(GlobalScope, CommandClient.ConnectionType.Status, this)
    private var receiverRegistered = false


    private val notificationBuilder by lazy {
        NotificationCompat.Builder(service, notificationChannel)
                .setShowWhen(false)
                .setOngoing(true)
                .setContentTitle("A-VPN")
                .setOnlyAlertOnce(true)
                .setSmallIcon(R.drawable.ic_stat_logo)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setBadgeIconType(NotificationCompat.BADGE_ICON_NONE)
                .setNumber(0)
                .setContentIntent(
                        PendingIntent.getActivity(
                                service,
                                0,
                                Intent(
                                        service,
                                        MainActivity::class.java
                                ).setFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
                                flags
                        )
                )
                .setPriority(NotificationCompat.PRIORITY_LOW).apply {
                    addAction(
                            NotificationCompat.Action.Builder(
                                    0, service.getText(R.string.stop), PendingIntent.getBroadcast(
                                    service,
                                    0,
                                    Intent(Action.SERVICE_CLOSE).setPackage(
                                        Application.application.packageName
                                    ),
                                    flags
                            )
                            ).build()
                    )
                }
    }

    fun show(profileName: String, @StringRes contentTextId: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Application.notification.deleteNotificationChannel(oldNotificationChannel)
            // the ongoing "connected" notification shouldn't put a count on the app icon
            Application.notification.createNotificationChannel(
                NotificationChannel(
                    notificationChannel, "A-VPN", NotificationManager.IMPORTANCE_LOW
                ).apply { setShowBadge(false) }
            )
        }
        service.startForeground(
            notificationId, notificationBuilder
                .setContentTitle(profileName.takeIf { it.isNotBlank() } ?: "A-VPN")
                .setContentText(service.getString(contentTextId)).build()
        )
    }


    /** The ongoing notification with a plain title and text (auto-pause). */
    fun showText(title: String, text: String) {
        stopListenSystemInfo()
        service.startForeground(
            notificationId, notificationBuilder.setContentTitle(title).setContentText(text).build()
        )
    }

    suspend fun start() {
        if (Settings.dynamicNotification && checkPermission()) {
//            commandClient.connect()
            startListenSystemInfo()
            withContext(Dispatchers.Main) {
                registerReceiver()
            }
        }
    }

    private fun registerReceiver() {
        service.registerReceiver(this, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        })
        receiverRegistered = true
    }

    private var lastContent: String? = null
    private var lastTitle: String? = null

    fun updateStatus(previous:SystemInfo,status: SystemInfo) {
        // A-VPN: the servers in use as the title ("БС" for the whitelist ones, "Wi-Fi" for the regular), then the
        // ping and loss through the VPN and the server ("Авто: 🇸🇪 Швеция 2")
        SessionTraffic.add(status)
        NotificationQuality.probe(SessionTraffic.sessionId())
        val outbound = status.current_outbound
        val whitelist = outbound.contains("lte only", ignoreCase = true) || outbound.contains("БС")
        val content = (NotificationQuality.line() ?: "Пинг —") + "\n" + SessionTraffic.serverLine(outbound)
        val title = if (whitelist) "БС" else "Wi-Fi"
        // posted only when the text changes: every post wakes the status bar and the always-on display, and the
        // totals change far less often than the core reports (once a second)
        if (content == lastContent && title == lastTitle) return
        lastContent = content
        lastTitle = title
        Application.notificationManager.notify(
                notificationId,
                notificationBuilder.setContentTitle(title).setContentText(content).build()
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON -> {
                startListenSystemInfo()
            }

            Intent.ACTION_SCREEN_OFF -> {
                stopListenSystemInfo()
            }
        }
    }

    fun close() {
        stopListenSystemInfo()
        ServiceCompat.stopForeground(service, ServiceCompat.STOP_FOREGROUND_REMOVE)
        if (receiverRegistered) {
            service.unregisterReceiver(this)
            receiverRegistered = false
        }
    }

    private var streamingJob: Job? = null

    fun startListenSystemInfo() {
        // Cancel any previous stream if still running
        Log.d("notification","startListenSystemInfo")
        streamingJob?.cancel()

        streamingJob = streamingCoroutineScope.launch(Dispatchers.IO) {
            Log.d("notification", "startListenSystemInfo-launch")

            val coreClient = GrpcClientProvider.grpcClient.create(CoreClient::class)

            try {
                var previous = coreClient.GetSystemInfo().executeBlocking(Empty())
                val power = service.getSystemService(Context.POWER_SERVICE) as PowerManager

                while (isActive) {
                    // nobody sees the notification (the screen is off, or its notifications are switched off): the core
                    // isn't asked, the ping isn't probed and nothing is posted; the screen coming on starts the stream
                    // again at once (see onReceive), and this wait is only for the cases that broadcast missed
                    if (unseen(power)) {
                        delay(5_000)
                        continue
                    }
                    delay(1_000) // ✅ coroutine-friendly
                    val current = coreClient.GetSystemInfo().executeBlocking(Empty())
                    updateStatus(previous,current)
                    previous = current
                }
            } catch (e: CancellationException) {
                // coroutine cancelled normally
                Log.d("notification", "SystemInfo polling cancelled")
                notification.cancel(notificationId)
            } catch (e: Exception) {
                Log.e("notification", "SystemInfo polling failed", e)
                notification.cancel(notificationId)
            }
        }
    }
    /** Nobody would see an update: the screen is off, or the app's notifications (or this channel) are off. */
    private fun unseen(power: PowerManager): Boolean {
        if (!power.isInteractive) return true
        if (!Application.notification.areNotificationsEnabled()) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = Application.notification.getNotificationChannel(notificationChannel)
            if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) return true
        }
        return false
    }

    fun stopListenSystemInfo(){
        try {
            streamingJob?.cancel()
        }catch (e: Exception){
            Log.d("notification", "Exception ${e}")
        }
    }
}