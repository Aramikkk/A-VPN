package com.hiddify.hiddify.bg

internal object ForegroundSampling {
    /**
     * How often the watcher wakes: every second while auto-pause has apps to watch and can see them, every ten
     * seconds when it can't see them, every fifteen while a home Wi-Fi is watched, else every ten seconds (there
     * is nothing to look at); a minute while the screen is off. The light background work doubles them all.
     */
    fun intervalMillis(
        autoPauseActive: Boolean,
        canObserve: Boolean,
        screenInteractive: Boolean,
        homeWatch: Boolean = false,
        lightBackground: Boolean = false,
    ): Long = base(autoPauseActive, canObserve, screenInteractive, homeWatch) * if (lightBackground) 2 else 1

    private fun base(
        autoPauseActive: Boolean,
        canObserve: Boolean,
        screenInteractive: Boolean,
        homeWatch: Boolean,
    ): Long = when {
        !screenInteractive -> 60_000L
        autoPauseActive && canObserve -> 1_000L
        autoPauseActive -> 10_000L
        homeWatch -> 15_000L
        else -> 10_000L
    }
}
