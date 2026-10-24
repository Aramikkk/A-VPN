package com.hiddify.hiddify

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.os.PowerManager
import androidx.core.content.getSystemService
import com.hiddify.hiddify.bg.AppChangeReceiver
import go.Seq
import com.hiddify.hiddify.Application as BoxApplication

class Application : Application() {

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        application = this
    }

    override fun onCreate() {
        super.onCreate()

        Seq.setContext(this)
        logProcessStart()

        registerReceiver(AppChangeReceiver(), IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addDataScheme("package")
        })
    }

    /**
     * A line for every start of the app's process, and (Android 11 and up) the reasons the earlier ones ended, from
     * the system's own record: low memory, killed by the system, a crash, the user's force stop...
     */
    private fun logProcessStart() {
        ServiceLog.write("process start pid=" + android.os.Process.myPid() + " " + BoxApplication.processLabel())
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.R) return
        try {
            val prefs = getSharedPreferences("service_log", Context.MODE_PRIVATE)
            val seen = prefs.getLong("exit_seen", 0L)
            val exits = getSystemService(android.app.ActivityManager::class.java)
                .getHistoricalProcessExitReasons(packageName, 0, 8)
            var newest = seen
            for (e in exits.sortedBy { it.timestamp }) {
                if (e.timestamp <= seen) continue
                newest = maxOf(newest, e.timestamp)
                ServiceLog.write(
                    "an earlier process ended: " + java.text.SimpleDateFormat("MM-dd HH:mm:ss", java.util.Locale.US)
                        .format(java.util.Date(e.timestamp)) + " " + e.processName + " reason=" + e.reason +
                        " (" + exitReason(e.reason) + ") status=" + e.status + " importance=" + e.importance +
                        " " + (e.description ?: ""),
                )
            }
            if (newest != seen) prefs.edit().putLong("exit_seen", newest).apply()
        } catch (t: Throwable) {
            ServiceLog.write("the earlier exits couldn't be read: " + t)
        }
    }

    private fun exitReason(code: Int): String = when (code) {
        1 -> "EXIT_SELF"
        2 -> "SIGNALED"
        3 -> "LOW_MEMORY"
        4 -> "CRASH"
        5 -> "CRASH_NATIVE"
        6 -> "ANR"
        7 -> "INITIALIZATION_FAILURE"
        8 -> "PERMISSION_CHANGE"
        9 -> "EXCESSIVE_RESOURCE_USAGE"
        10 -> "USER_REQUESTED"
        11 -> "USER_STOPPED"
        12 -> "DEPENDENCY_DIED"
        13 -> "OTHER"
        14 -> "FREEZER"
        15 -> "PACKAGE_STATE_CHANGE"
        16 -> "PACKAGE_UPDATED"
        else -> "UNKNOWN"
    }

    companion object {
        fun processLabel(): String = try {
            android.app.Application.getProcessName() ?: ""
        } catch (_: Throwable) {
            ""
        }

        lateinit var application: BoxApplication
        val notification by lazy { application.getSystemService<NotificationManager>()!! }
        val connectivity by lazy { application.getSystemService<ConnectivityManager>()!! }
        val packageManager by lazy { application.packageManager }
        val powerManager by lazy { application.getSystemService<PowerManager>()!! }
        val notificationManager by lazy { application.getSystemService<NotificationManager>()!! }


    }

}