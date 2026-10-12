package com.hiddify.hiddify

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Switches the home-screen icon to the colour theme's: enables its launcher alias and disables the others. */
class AppIconHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        const val channelName = "com.aravpn.app/icon"
        val colours = listOf("red", "blue", "emerald", "orange", "violet", "teal", "gold")
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
        val context = context ?: return result.error("no_context", null, null)
        when (call.method) {
            "setIcon" -> {
                val wanted = call.arguments as? String ?: "red"
                if (wanted !in colours) return result.error("unknown_icon", wanted, null)
                result.success(setIcon(context, wanted))
            }
            else -> result.notImplemented()
        }
    }

    /** Returns whether anything changed: the launcher redraws (and may briefly drop the icon) only then. */
    private fun setIcon(context: Context, wanted: String): Boolean {
        val pm = context.packageManager
        var changed = false
        // enable the wanted one first, so there's never a moment without a launcher entry
        for (colour in listOf(wanted) + colours.filter { it != wanted }) {
            val component = ComponentName(context.packageName, "com.hiddify.hiddify.Launcher${colour.replaceFirstChar { it.uppercase() }}")
            val state = if (colour == wanted) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            if (pm.getComponentEnabledSetting(component) == state) continue
            // the red one is enabled in the manifest: "default" counts as enabled for it
            if (colour == "red" && state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED &&
                pm.getComponentEnabledSetting(component) == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) continue
            pm.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
            changed = true
        }
        return changed
    }
}
