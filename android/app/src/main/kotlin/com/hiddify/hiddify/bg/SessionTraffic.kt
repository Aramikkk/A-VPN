package com.hiddify.hiddify.bg

import com.hiddify.core.api.v2.hcore.SystemInfo

/**
 * The VPN session's traffic for the notification: how much went through the VPN and how much direct.
 *
 * A-VPN's core sends the VPN totals and the session's start as extra SystemInfo fields (100: VPN up, 101: VPN
 * down, 102: session start), which the generated code keeps as unknown fields. Its counters restart at every
 * reload (a network or server change); this adds them up for the whole session, as the app's Statistics tab does.
 */
object SessionTraffic {
    private var session = 0L
    private var carriedTotal = 0L
    private var carriedVpn = 0L
    private var lastTotal = 0L
    private var lastVpn = 0L

    /** (through the VPN, direct) in bytes, for the session so far. */
    @Synchronized
    fun add(status: SystemInfo): Pair<Long, Long> {
        val extra = unknownVarints(status.unknownFields.toByteArray())
        val total = status.uplink_total + status.downlink_total
        val vpn = (extra[100] ?: 0L) + (extra[101] ?: 0L)
        val started = extra[102] ?: 0L
        if (started == 0L || started != session) {
            session = started
            carriedTotal = 0
            carriedVpn = 0
        } else if (total < lastTotal) {
            // the core's counters went back to zero within the session: keep what they had counted
            carriedTotal += lastTotal
            carriedVpn += lastVpn
        }
        lastTotal = total
        lastVpn = vpn
        val sessionVpn = carriedVpn + vpn
        val sessionTotal = carriedTotal + total
        return Pair(sessionVpn, (sessionTotal - sessionVpn).coerceAtLeast(0))
    }

    /** The current session's start, as the core reports it (0 before the first report). */
    @Synchronized
    fun sessionId(): Long = session

    /** The varint fields of a protobuf message's raw bytes, by field number. */
    fun unknownVarints(bytes: ByteArray): Map<Int, Long> {
        val out = HashMap<Int, Long>()
        var i = 0
        fun varint(): Long {
            var result = 0L
            var shift = 0
            while (i < bytes.size) {
                val b = bytes[i++].toInt() and 0xFF
                result = result or ((b and 0x7F).toLong() shl shift)
                if (b and 0x80 == 0) break
                shift += 7
            }
            return result
        }
        while (i < bytes.size) {
            val tag = varint()
            val field = (tag ushr 3).toInt()
            when ((tag and 7).toInt()) {
                0 -> out[field] = varint()
                1 -> i += 8
                2 -> i += varint().toInt()
                5 -> i += 4
                else -> return out
            }
        }
        return out
    }

    /** "12,4 МБ": one decimal under 100, none above, no ",0". */
    fun format(bytes: Long): String {
        val units = arrayOf("Б", "КБ", "МБ", "ГБ", "ТБ")
        var value = bytes.toDouble()
        var unit = 0
        while (value >= 1024 && unit < units.size - 1) {
            value /= 1024
            unit++
        }
        var text = if (unit == 0 || value >= 100) Math.round(value).toString() else String.format(java.util.Locale.US, "%.1f", value)
        if (text.endsWith(".0")) text = text.dropLast(2)
        return "${text.replace('.', ',')} ${units[unit]}"
    }

    /** "Авто: 🇸🇪 Швеция 2" from the core's "lowest→🇸🇪 Доступ - Швеция 2"; a chosen server keeps its name. */
    fun serverLine(currentOutbound: String): String {
        val parts = currentOutbound.split("→")
        val auto = parts.size > 1 && parts[0].trim() in setOf("lowest", "balance")
        // without the core's "§ 15" numbering
        var name = parts.last().replace("§hide§", "").replace(Regex("""\s*§\s*\d+\s*$"""), "")
            .replace(Regex("Доступ", RegexOption.IGNORE_CASE), "Sigma").trim()
        if (auto) {
            // the flag and the country, without the provider's prefix
            val flag = Regex("^\\S+\\s").find(name)?.value?.takeIf { it.codePoints().anyMatch { c -> c in 0x1F1E6..0x1F1FF } } ?: ""
            val rest = name.removePrefix(flag)
            val dash = rest.indexOf(" - ")
            name = flag + if (dash >= 0) rest.substring(dash + 3).trim() else rest
            return "Авто: $name"
        }
        return name
    }

    fun profileName(name: String) =
        name.replace(Regex("Доступ", RegexOption.IGNORE_CASE), "Sigma").ifBlank { "A-VPN" }
}
