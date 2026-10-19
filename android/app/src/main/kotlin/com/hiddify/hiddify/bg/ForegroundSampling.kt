package com.hiddify.hiddify.bg

internal object ForegroundSampling {
    fun intervalMillis(autoPauseActive: Boolean, canObserve: Boolean, screenInteractive: Boolean): Long = when {
        !screenInteractive -> 60_000L
        !canObserve -> 10_000L
        autoPauseActive -> 1_000L
        else -> 5_000L
    }
}
