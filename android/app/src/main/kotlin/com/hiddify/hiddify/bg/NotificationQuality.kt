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

    // when the last probe went out: once every three seconds
    private var lastProbe = 0L

    /** Starts a probe unless one is out; [sessionId] changing (a new connection) starts the minute over. */
    @Synchronized
    fun probe(sessionId: Long) {
        if (sessionId != session) {
            session = sessionId
            samples.clear()
            warmedUp = false
            // a new connection: the kept one went with the old
            worker.execute { drop() }
        }
        if (inFlight || !prefs.getBoolean("flutter.enable-mixed-port", true)) return
        // once every three seconds, as the app does
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastProbe < 3000) return
        lastProbe = now
        inFlight = true
        val forSession = session
        val port = port()
        val target = url()
        worker.execute { add(forSession, measure(port, target)) }
    }

    // one connection kept open through the proxy, as the app's own probes do (a new one each time measured the
    // proxy's way out too, about three times the app's ping)
    private var socket: Socket? = null

    private fun drop() {
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        socket = null
    }

    /** One HEAD through the proxy; the time to the answer's headers in ms, or null when it doesn't come in time. */
    private fun measure(port: Int, target: String): Long? {
        for (attempt in 0..1) {
            try {
                val uri = URI(target)
                val host = uri.host ?: "www.gstatic.com"
                val s = socket ?: Socket().also {
                    it.soTimeout = TIMEOUT_MS
                    it.connect(InetSocketAddress("127.0.0.1", port), TIMEOUT_MS)
                    socket = it
                }
                val started = System.nanoTime()
                val crlf = "\r\n"
                val request = "HEAD $target HTTP/1.1${crlf}Host: $host${crlf}Connection: keep-alive${crlf}" +
                    "User-Agent: A-VPN$crlf$crlf"
                s.getOutputStream().apply {
                    write(request.toByteArray())
                    flush()
                }
                // the status line and the headers up to the blank line (a HEAD has no body)
                val input = s.getInputStream()
                val status = readLine(input) ?: throw java.io.IOException("closed")
                var closeAfter = false
                while (true) {
                    val line = readLine(input) ?: throw java.io.IOException("closed")
                    if (line.isEmpty()) break
                    if (line.startsWith("Connection:", ignoreCase = true) && line.contains("close", ignoreCase = true)) {
                        closeAfter = true
                    }
                }
                val ms = (System.nanoTime() - started) / 1_000_000
                if (closeAfter) drop()
                return if (status.startsWith("HTTP/")) ms else null
            } catch (_: java.net.SocketTimeoutException) {
                drop()
                return null
            } catch (_: Exception) {
                // the kept connection had gone (closed by the proxy): once more on a new one
                drop()
                if (attempt == 1) return null
            }
        }
        return null
    }

    private fun readLine(input: java.io.InputStream): String? {
        val out = StringBuilder()
        while (true) {
            val b = input.read()
            if (b < 0) return if (out.isEmpty()) null else out.toString()
            if (b == '\n'.code) return out.toString().trimEnd('\r')
            out.append(b.toChar())
        }
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
