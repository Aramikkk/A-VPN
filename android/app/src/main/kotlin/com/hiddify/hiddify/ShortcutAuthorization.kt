package com.hiddify.hiddify

import java.security.MessageDigest

internal object ShortcutAuthorization {
    const val TOKEN_EXTRA = "com.aravpn.shortcut.TOKEN"

    fun isTrusted(action: String?, suppliedToken: String?, expectedToken: String): Boolean =
        action == "android.intent.action.MAIN" && expectedToken.length >= 32 &&
            suppliedToken != null && MessageDigest.isEqual(
                suppliedToken.toByteArray(Charsets.UTF_8), expectedToken.toByteArray(Charsets.UTF_8))
}
