package com.hiddify.hiddify

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * A-VPN's own small tools for the Dart side:
 *  - "appIcon": an app's icon as a picture (an adaptive icon with its two layers, as the launcher draws it), for the
 *    apps the installed-apps list gave none for;
 *  - "install": the downloaded update (an APK in the cache's ara_update folder) handed to the system's installer.
 */
class AraToolsHandler : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.aravpn.app/tools"
        private const val ICON_SIZE = 192
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "appIcon" -> {
                val pkg = call.argument<String>("package")
                result.success(if (pkg == null) null else try { icon(pkg) } catch (e: Exception) { null })
            }
            "install" -> {
                val path = call.argument<String>("path")
                result.success(if (path == null) "error" else try { install(path) } catch (e: Exception) { "error" })
            }
            else -> result.notImplemented()
        }
    }

    private fun icon(pkg: String): ByteArray? {
        val ctx = context ?: return null
        val drawable = ctx.packageManager.getApplicationIcon(pkg)
        val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
        drawable.draw(canvas)
        ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            return stream.toByteArray()
        }
    }

    private fun install(path: String): String {
        val ctx = context ?: return "error"
        // the user lets this app install apps once; until then the settings page for it opens
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !ctx.packageManager.canRequestPackageInstalls()) {
            val settings = Intent(
                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:" + ctx.packageName),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(settings)
            return "permission"
        }
        val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".updates", File(path))
        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(view)
        return "ok"
    }
}
