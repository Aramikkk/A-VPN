package com.hiddify.hiddify

import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The VPN service's own log, a line a thing that happens to it (it starts, stops and why, the system takes the VPN
 * over or asks for memory, the night mode puts the core to sleep): next to the app's log, in logs/service-<day>.log,
 * and put into the exported log. The app's log can't say why the service went when the app itself was gone.
 */
object ServiceLog {
    private const val LIMIT = 300_000L

    @Synchronized
    fun write(event: String) {
        try {
            val now = Date()
            val dir = File(Application.application.getExternalFilesDir(null), "logs")
            dir.mkdirs()
            val file = File(dir, "service-" + SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now) + ".log")
            if (file.length() > LIMIT) return
            file.appendText(SimpleDateFormat("HH:mm:ss.SSS", Locale.US).format(now) + " [SERVICE] " + event + "\n")
        } catch (_: Throwable) {
            // a log that fails must not fail what it logs
        }
    }

    /** where the call came from, a few frames up, for the line of a stop */
    fun caller(): String =
        Throwable().stackTrace.drop(2).take(5).joinToString(" < ") { it.className.substringAfterLast('.') + "." + it.methodName }
}
