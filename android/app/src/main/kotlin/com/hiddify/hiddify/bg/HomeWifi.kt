package com.hiddify.hiddify.bg

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import com.hiddify.hiddify.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.net.Inet4Address
import java.net.InetSocketAddress

/**
 * A-VPN home Wi-Fi: the VPN pauses on a Wi-Fi whose router already runs a VPN, and comes back off it. A home is
 * told by its router, with no location permission (Android hides the Wi-Fi's name without it): the router's
 * address on the Wi-Fi and the ports its VPN panel answers on (zashboard, Clash API, a proxy port). Another
 * router with the same address (Xiaomi's 192.168.31.1 is common) has no such panel, so it doesn't pass for home.
 */
object HomeWifi {
    /** The ports a router's VPN panel or proxy usually answers on: zashboard, Clash API, a mixed proxy. */
    val markerPorts = listOf(3058, 9090, 9091, 9999, 7890)

    data class Router(val gateway: String, val ports: List<Int>) {
        fun toJson(): JSONObject = JSONObject().put("gateway", gateway).put("ports", JSONArray(ports))
    }

    /** The homes the app saved (Settings), as JSON [{"name", "gateway", "ports"}]. */
    fun parse(json: String): List<Router> = runCatching {
        val list = JSONArray(json)
        (0 until list.length()).mapNotNull { i ->
            val item = list.optJSONObject(i) ?: return@mapNotNull null
            val gateway = item.optString("gateway")
            val ports = item.optJSONArray("ports") ?: JSONArray()
            if (gateway.isBlank() || ports.length() == 0) null
            else Router(gateway, (0 until ports.length()).map { ports.getInt(it) })
        }
    }.getOrDefault(emptyList())

    @Suppress("DEPRECATION") // allNetworks is the one call that lists every network, VPN or not
    private fun wifi(cm: ConnectivityManager): Network? = cm.allNetworks.firstOrNull { network ->
        val caps = cm.getNetworkCapabilities(network) ?: return@firstOrNull false
        caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) && !caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }

    /** The Wi-Fi's router: the default route's IPv4 gateway on it. */
    private fun gateway(cm: ConnectivityManager, network: Network): String? =
        cm.getLinkProperties(network)?.routes
            ?.firstOrNull { it.isDefaultRoute && it.gateway is Inet4Address }
            ?.gateway?.hostAddress

    /** Whether [port] on [host] answers, asked over the Wi-Fi itself (past the VPN). */
    private fun answers(network: Network, host: String, port: Int): Boolean = runCatching {
        network.socketFactory.createSocket().use { socket ->
            socket.connect(InetSocketAddress(host, port), 1500)
            true
        }
    }.getOrDefault(false)

    /** [answers] twice: one lost packet on a busy or sleeping Wi-Fi isn't a router without its panel. */
    private fun answersWell(network: Network, host: String, port: Int): Boolean =
        answers(network, host, port) || answers(network, host, port)

    /** The router of the Wi-Fi the phone is on now, with the marker ports it answers on; null off Wi-Fi. */
    fun capture(context: Context): Router? {
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return null
        val network = wifi(cm) ?: return null
        val gateway = gateway(cm, network) ?: return null
        val ports = markerPorts.filter { answers(network, gateway, it) }
        return Router(gateway, ports)
    }

    /** How sure the look at the Wi-Fi is: [UNSURE] is the home's router address with its panel not answering now. */
    enum class Verdict { HOME, AWAY, UNSURE }

    /** Whether the phone is on one of the saved homes now: its router's address and every port saved for it. */
    fun verdict(context: Context): Verdict {
        val homes = parse(Settings.homeWifiList)
        if (homes.isEmpty()) return Verdict.AWAY
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return Verdict.AWAY
        val network = wifi(cm) ?: return Verdict.AWAY
        val gateway = gateway(cm, network) ?: return Verdict.AWAY
        val same = homes.filter { it.gateway == gateway }
        if (same.isEmpty()) return Verdict.AWAY
        return if (same.any { home -> home.ports.all { answersWell(network, gateway, it) } }) Verdict.HOME else Verdict.UNSURE
    }

    fun atHome(context: Context): Boolean = verdict(context) == Verdict.HOME
}
