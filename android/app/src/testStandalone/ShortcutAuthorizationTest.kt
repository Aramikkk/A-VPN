package com.hiddify.hiddify

fun main() {
    val secret = "a".repeat(43)
    check(!ShortcutAuthorization.isTrusted(null, null, secret)) { "arbitrary explicit launch must not toggle VPN" }
    check(!ShortcutAuthorization.isTrusted("android.intent.action.MAIN", null, secret)) { "legacy shortcut needs confirmation" }
    check(!ShortcutAuthorization.isTrusted("android.intent.action.MAIN", "wrong", secret))
    check(!ShortcutAuthorization.isTrusted("android.intent.action.MAIN", "", ""))
    check(!ShortcutAuthorization.isTrusted("other", secret, secret))
    check(ShortcutAuthorization.isTrusted("android.intent.action.MAIN", secret, secret)) { "created shortcut must still toggle" }
    println("ShortcutAuthorization: 6 checks passed")
}
