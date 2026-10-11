package com.hiddify.hiddify.bg

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

/**
 * Which app is on screen, from the usage events Android records. Needs the "usage access" permission, which
 * the user grants once in the phone's settings (A-VPN opens that screen).
 */
object ForegroundApp {
    private var current: String? = null
    private var lastQuery = 0L

    fun hasPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** The package last brought to the foreground, or null when nothing is known yet. */
    @Synchronized
    fun current(context: Context): String? {
        val usage = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        // the first look goes back a few minutes; later ones read only what happened since
        val from = if (lastQuery == 0L) now - 5 * 60_000 else lastQuery - 2_000
        val events = usage.queryEvents(from, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) current = event.packageName
        }
        lastQuery = now
        return current
    }

    /** Forgets what it knew, so a new watch starts from the recent history. */
    @Synchronized
    fun reset() {
        current = null
        lastQuery = 0L
    }
}
