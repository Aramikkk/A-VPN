package com.hiddify.hiddify

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Tells Flutter which physical network the phone uses under the VPN. The active network is the VPN itself
 * while it runs, so this looks at every other network instead: a validated Wi-Fi (or Ethernet) wins, else
 * a mobile one.
 */
class NetworkTypeHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        const val channelName = "com.aravpn.app/network"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, channelName).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "underlyingNetwork" -> result.success(NetworkKinds.underlying(context))
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
