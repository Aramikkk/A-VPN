package com.hiddify.hiddify

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Tells Flutter which physical network the phone uses under the VPN. The active network is the VPN itself
 * while it runs, so this looks at every other network instead: a validated Wi-Fi (or Ethernet) wins, else
 * a mobile one.
 */
class NetworkTypeHandler : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var channel: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var context: Context? = null
    private val handler = Handler(Looper.getMainLooper())
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var publishTask: Runnable? = null

    companion object {
        const val channelName = "com.aravpn.app/network"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, channelName).also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, "$channelName/events").also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        stopMonitoring()
        sink = null
        events = null
        channel = null
        context = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        stopMonitoring()
        sink = events
        publish()
        val manager = context?.getSystemService(ConnectivityManager::class.java) ?: return
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: android.net.Network) = publish()
            override fun onLost(network: android.net.Network) = publish()
            override fun onCapabilitiesChanged(
                network: android.net.Network,
                networkCapabilities: NetworkCapabilities
            ) = publish()
        }
        try {
            manager.registerNetworkCallback(NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(), callback)
            networkCallback = callback
        } catch (_: RuntimeException) {
            networkCallback = null
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        stopMonitoring()
    }

    private fun publish() {
        publishTask?.let(handler::removeCallbacks)
        val task = Runnable {
            publishTask = null
            sink?.success(NetworkKinds.underlying(context))
        }
        publishTask = task
        handler.postDelayed(task, 250)
    }

    private fun stopMonitoring() {
        publishTask?.let(handler::removeCallbacks)
        publishTask = null
        val callback = networkCallback ?: return
        try {
            context?.getSystemService(ConnectivityManager::class.java)?.unregisterNetworkCallback(callback)
        } catch (_: RuntimeException) {
            // The system can detach the callback while the engine is shutting down.
        }
        networkCallback = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "underlyingNetwork" -> result.success(NetworkKinds.underlying(context))
            // a VPN up on the phone now (A-VPN's own, left running while Android unloaded the app)
            "vpnActive" -> {
                val cm = context?.getSystemService(ConnectivityManager::class.java)
                @Suppress("DEPRECATION")
                val up = cm?.allNetworks?.any {
                    cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
                } ?: false
                result.success(up)
            }
            // the router of the Wi-Fi the phone is on, to save it as a home: its address and the VPN panel's ports
            "homeWifiCapture" -> {
                val appContext = context?.applicationContext
                Thread {
                    val router = appContext?.let { com.hiddify.hiddify.bg.HomeWifi.capture(it) }
                    val answer = router?.let { mapOf("gateway" to it.gateway, "ports" to it.ports) }
                    android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(answer) }
                }.start()
            }
            // the service switches the config by itself when it has both variants: where it stands, else null
            "serviceAppliedNetwork" -> result.success(
                if (Settings.networkConfig("wifi").isNotBlank() && Settings.networkConfig("mobile").isNotBlank())
                    Settings.appliedNetwork else null
            )
            else -> result.notImplemented()
        }
    }

}

object NetworkKinds {
    @Suppress("DEPRECATION") // allNetworks is the one call that lists every network, VPN or not
    fun underlying(context: Context?): String {
        val cm = context?.getSystemService(ConnectivityManager::class.java) ?: return "unknown"
        var wifi = false
        var mobile = false
        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
            if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) continue
            if ((caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            ) {
                wifi = true
            }
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) mobile = true
        }
        return when {
            wifi -> "wifi"
            mobile -> "mobile"
            else -> "unknown"
        }
    }
}
