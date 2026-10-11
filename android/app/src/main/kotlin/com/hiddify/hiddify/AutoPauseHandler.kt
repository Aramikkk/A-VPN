package com.hiddify.hiddify

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings as AndroidSettings
import com.hiddify.hiddify.bg.ForegroundApp
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Auto-pause settings screen helpers: whether usage access is granted, and opening the screen that grants it. */
class AutoPauseHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        const val channelName = "com.aravpn.app/autopause"
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
            "hasUsageAccess" -> result.success(ForegroundApp.hasPermission(context))
            "openUsageAccessSettings" -> {
                // straight to A-VPN's own switch where the phone allows it, else the list of apps
                val direct = Intent(AndroidSettings.ACTION_USAGE_ACCESS_SETTINGS)
                    .setData(Uri.parse("package:${context.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                val list = Intent(AndroidSettings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    context.startActivity(direct)
                } catch (e: Exception) {
                    context.startActivity(list)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
