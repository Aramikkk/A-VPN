package com.hiddify.hiddify

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.hiddify.hiddify.bg.BoxService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * A-VPN's own small tools for the Dart side:
 *  - "appIcon": an app's icon as a picture (an adaptive icon with its two layers, as the launcher draws it), for the
 *    apps the installed-apps list gave none for;
 *  - "pauseState": whether the service has paused the VPN (a home Wi-Fi, or an app that is on screen);
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
                if (pkg == null) {
                    result.success(null)
                } else {
                    // the icon (or null) and, when there is none, what each source said, for the app's log
                    val why = StringBuilder()
                    val icon = try { icon(pkg, why) } catch (e: Exception) { why.append(" error ").append(e); null }
                    result.success(mapOf("icon" to icon, "why" to why.toString()))
                }
            }
            // the service's pause: "" not paused, "home", or "app:" and the app's name (see BoxService.pauseState)
            "pauseState" -> result.success(BoxService.pauseState)
            "install" -> {
                val path = call.argument<String>("path")
                val allowSettings = call.argument<Boolean>("allowSettings") ?: true
                result.success(if (path == null) "error" else try { install(path, allowSettings) } catch (e: Exception) { "error" })
            }
            else -> result.notImplemented()
        }
    }

    /**
     * An app's icon as a PNG. The usual application icon first; some apps give an empty one (an adaptive icon whose layers
     * draw nothing as such), so the icon of the app's launcher activity, then the one from its application info, then
     * the themed (monochrome) layer on a dark tile are tried, and a picture with nothing in it is never taken.
     */
    private fun icon(pkg: String, why: StringBuilder): ByteArray? {
        val ctx = context ?: return null
        val pm = ctx.packageManager
        val sources = listOf<() -> Drawable?>(
            { pm.getApplicationIcon(pkg) },
            { pm.getLaunchIntentForPackage(pkg)?.let { pm.getActivityIcon(it) } },
            { pm.getApplicationInfo(pkg, 0).loadUnbadgedIcon(pm) },
        )
        for ((index, source) in sources.withIndex()) {
            val drawable = try { source() } catch (e: Exception) { why.append(" [$index: ${e.javaClass.simpleName}]"); null }
            if (drawable == null) { why.append(" [$index: none]"); continue }
            val bitmap = try { render(drawable) } catch (e: Exception) { why.append(" [$index: draw ${e.javaClass.simpleName}]"); null } ?: continue
            if (!blank(bitmap)) return png(bitmap)
            why.append(" [$index: ${drawable.javaClass.simpleName} blank]")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val adaptive = try { pm.getApplicationIcon(pkg) as? AdaptiveIconDrawable } catch (e: Exception) { null }
            val mono = adaptive?.monochrome
            if (mono != null) {
                val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                canvas.drawRoundRect(
                    0f, 0f, ICON_SIZE.toFloat(), ICON_SIZE.toFloat(), ICON_SIZE * 0.27f, ICON_SIZE * 0.27f,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(27, 27, 29) },
                )
                val layer = mono.mutate()
                layer.setTint(Color.WHITE)
                // an adaptive layer is 108 dp with 72 dp showing: drawn bigger by that much
                val pad = ICON_SIZE / 4
                layer.setBounds(-pad, -pad, ICON_SIZE + pad, ICON_SIZE + pad)
                layer.draw(canvas)
                if (!blank(bitmap)) return png(bitmap)
            }
        }
        android.util.Log.w("AraTools", "no icon for $pkg:$why")
        return null
    }

    private fun render(drawable: Drawable): Bitmap? {
        val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
        drawable.draw(canvas)
        return bitmap
    }

    /** Nothing in it: every sampled pixel is clear, or they are all one colour. */
    private fun blank(bitmap: Bitmap): Boolean {
        val step = ICON_SIZE / 12
        var first: Int? = null
        var different = false
        var visible = false
        var y = step / 2
        while (y < ICON_SIZE) {
            var x = step / 2
            while (x < ICON_SIZE) {
                val pixel = bitmap.getPixel(x, y)
                if (Color.alpha(pixel) > 8) visible = true
                if (first == null) first = pixel else if (pixel != first) different = true
                x += step
            }
            y += step
        }
        return !visible || !different
    }

    private fun png(bitmap: Bitmap): ByteArray = ByteArrayOutputStream().use { stream ->
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        stream.toByteArray()
    }

    private fun install(path: String, allowSettings: Boolean): String {
        val ctx = context ?: return "error"
        // the user lets this app install apps once; until then the settings page for it opens
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !ctx.packageManager.canRequestPackageInstalls()) {
            // by itself (not asked for by the user) the settings page is not thrown open: only said
            if (!allowSettings) return "permission"
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
