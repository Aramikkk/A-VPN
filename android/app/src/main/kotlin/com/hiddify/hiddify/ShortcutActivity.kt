package com.hiddify.hiddify

import android.app.AlertDialog
import android.app.Activity
import android.content.Intent
import android.content.pm.ShortcutManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.getSystemService
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.hiddify.hiddify.bg.BoxService
import com.hiddify.hiddify.bg.ServiceConnection
import com.hiddify.hiddify.constant.Status

class ShortcutActivity : Activity(), ServiceConnection.Callback {

    private var toggleRequested = false

    private val connection = ServiceConnection(this, this, false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent.action == Intent.ACTION_CREATE_SHORTCUT) {
            // The exported shortcut creator must not hand its capability to an
            // arbitrary caller without the user's consent.
            AlertDialog.Builder(this)
                .setTitle(R.string.quick_toggle)
                .setMessage(R.string.confirm_shortcut_create)
                .setPositiveButton(android.R.string.ok) { _, _ -> createShortcut() }
                .setNegativeButton(android.R.string.cancel) { _, _ -> finish() }
                .setOnCancelListener { finish() }
                .show()
        } else if (ShortcutAuthorization.isTrusted(
                intent.action, intent.getStringExtra(ShortcutAuthorization.TOKEN_EXTRA), Settings.shortcutSecret)) {
            requestToggle()
        } else {
            // Static/old launcher shortcuts have no install token. Keep them usable,
            // but an arbitrary exported intent must never silently control the VPN.
            AlertDialog.Builder(this)
                .setTitle(R.string.quick_toggle)
                .setMessage(R.string.confirm_shortcut_toggle)
                .setPositiveButton(android.R.string.ok) { _, _ -> requestToggle() }
                .setNegativeButton(android.R.string.cancel) { _, _ -> finish() }
                .setOnCancelListener { finish() }
                .show()
        }
    }

    private fun createShortcut() {
        setResult(
            RESULT_OK, ShortcutManagerCompat.createShortcutResultIntent(
                this,
                ShortcutInfoCompat.Builder(this, "toggle")
                    .setIntent(
                        Intent(
                            this,
                            ShortcutActivity::class.java
                        ).setAction(Intent.ACTION_MAIN)
                            .putExtra(ShortcutAuthorization.TOKEN_EXTRA, Settings.shortcutSecret)
                    )
                    .setIcon(
                        IconCompat.createWithResource(
                            this,
                            R.mipmap.ic_launcher
                        )
                    )
                    .setShortLabel(getString(R.string.quick_toggle))
                    .build()
            )
        )
        finish()
    }

    private fun requestToggle() {
        toggleRequested = true
        connection.connect()
        if (Build.VERSION.SDK_INT >= 25) {
            getSystemService<ShortcutManager>()?.reportShortcutUsed("toggle")
        }
        moveTaskToBack(true)
    }

    override fun onServiceStatusChanged(status: Status) {
        if (!toggleRequested) return
        if (status != Status.Started && status != Status.Stopped) return
        toggleRequested = false
        when (status) {
            Status.Started -> BoxService.stop()
            Status.Stopped -> BoxService.start()
            else -> {}
        }
        finish()
    }

    override fun onDestroy() {
        connection.disconnect()
        super.onDestroy()
    }

}