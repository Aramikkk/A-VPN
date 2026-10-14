package com.hiddify.hiddify.bg

import android.content.Context
import com.hiddify.hiddify.Application
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Proxy
import java.util.concurrent.TimeUnit

/**
 * Ping through the VPN and packet loss for the notification, as the app's own probes: a tiny request to the
 * connection test URL through A-VPN's proxy port, so it takes the traffic's path; no answer in 2 seconds counts as
 * lost. A minute of probes is kept, for the session only; the first answer after the session starts is the tunnel
 * warming up and doesn't count.
 */
object NotificationQuality {
    private const val KEEP = 60
    private val samples = ArrayDeque<Long?>()
    private var session = Long.MIN_VALUE
    private var warmedUp = false
    private var inFlight = false
    private var client: OkHttpClient? = null
    private var clientPort = -1

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
        val port = port()
        if (client == null || port != clientPort) {
            clientPort = port
            client = OkHttpClient.Builder()
                .proxy(Proxy(Proxy.Type.HTTP, InetSocketAddress("127.0.0.1", port)))
                .connectTimeout(2, TimeUnit.SECONDS)
                .readTimeout(2, TimeUnit.SECONDS)
                .callTimeout(2, TimeUnit.SECONDS)
                .build()
        }
        inFlight = true
        val started = System.nanoTime()
        val forSession = session
        client!!.newCall(Request.Builder().url(url()).head().build()).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) = add(forSession, null)
            override fun onResponse(call: Call, response: Response) {
                response.close()
                add(forSession, (System.nanoTime() - started) / 1_000_000)
            }
        })
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
