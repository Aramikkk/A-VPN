package com.hiddify.hiddify.bg

import android.content.Context
import com.hiddify.hiddify.Application
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URI
import java.util.concurrent.Executors

/**
 * Ping through the VPN and packet loss for the notification, as the app's own probes: a tiny request to the
 * connection test URL through A-VPN's proxy port, so it takes the traffic's path; no answer in 2 seconds counts as
 * lost. A minute of probes is kept, for the session only; the first answer after the session starts is the tunnel
 * warming up and doesn't count.
 *
 * Spoken straight to the proxy over a socket: an HTTP client (OkHttp) holds to the app's cleartext rule, which
 * allows plain HTTP to 127.0.0.1 only, and refused every probe to the test URL.
 */
object NotificationQuality {
    private const val KEEP = 60
    private const val TIMEOUT_MS = 2_000
    private val samples = ArrayDeque<Long?>()
    private var session = Long.MIN_VALUE
    private var warmedUp = false
    private var inFlight = false
    private val worker = Executors.newSingleThreadExecutor()

    private val prefs by lazy {
        Application.application.applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    private fun port(): Int = try {
        prefs.getLong("flutter.mixed-port", 12334L).toInt()
    } catch (_: ClassCastException) {
        12334
    }

    private fun url(): String =
        prefs.getString("flutter.connection-test-url", null)?.takeIf { it.isNotBlank() }
            ?: "http://www.gstatic.com/generate_204"

    /** Starts a probe unless one is out; [sessionId] changing (a new connection) starts the minute over. */
    @Synchronized
    fun probe(sessionId: Long) {
        if (sessionId != session) {
            session = sessionId
            samples.clear()
            warmedUp = false
        }
        if (inFlight || !prefs.getBoolean("flutter.enable-mixed-port", true)) return
        inFlight = true
        val forSession = session
        val port = port()
        val target = url()
        worker.execute { add(forSession, measure(port, target)) }
    }

    /** One HEAD through the proxy; the time to the status line in ms, or null when it doesn't come in time. */
    private fun measure(port: Int, target: String): Long? = try {
        val uri = URI(target)
        val host = uri.host ?: "www.gstatic.com"
        val started = System.nanoTime()
        Socket().use { socket ->
            socket.soTimeout = TIMEOUT_MS
            socket.connect(InetSocketAddress("127.0.0.1", port), TIMEOUT_MS)
            val request = "HEAD $target HTTP/1.1\r\nHost: $host\r\nConnection: close\r\nUser-Agent: A-VPN\r\n\r\n"
            socket.getOutputStream().apply {
                write(request.toByteArray())
                flush()
            }
            // the status line, "HTTP/1.1 204 No Content": any HTTP answer means it got through
            val line = socket.getInputStream().bufferedReader().readLine()
            if (line != null && line.startsWith("HTTP/")) (System.nanoTime() - started) / 1_000_000 else null
        }
    } catch (_: Exception) {
        null
    }

    @Synchronized
    private fun add(forSession: Long, ms: Long?) {
        inFlight = false
        if (forSession != session) return
        // nothing counts before the first answer, nor that answer itself (the tunnel warming up)
        if (!warmedUp) {
            if (ms != null) warmedUp = true
            return
        }
        samples.addLast(ms)
        while (samples.size > KEEP) samples.removeFirst()
    }

    /** "Пинг 64 ms · потери 0%", or null before the first counted answer. */
    @Synchronized
    fun line(): String? {
        val ping = samples.lastOrNull { it != null } ?: return null
        val loss = samples.count { it == null } * 100.0 / samples.size
        val lossText = when {
            loss == 0.0 -> "0%"
            loss < 10 -> String.format(java.util.Locale.US, "%.1f%%", loss)
            else -> "${Math.round(loss)}%"
        }
        return "Пинг $ping ms · потери $lossText"
    }
}
