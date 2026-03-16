package com.deeplink.sdk

import android.util.Log

/**
 * Internal debug logger. Enable via `DeeplinkSDK.setDebug(true)`.
 * All logs are tagged "[Deeplink]" and use Android's `Log` API.
 */
internal object DeeplinkLogger {
    @Volatile var isEnabled = false
    private const val TAG = "DeeplinkSDK"

    fun log(message: String) {
        if (isEnabled) Log.d(TAG, "[Deeplink] $message")
    }

    fun error(message: String, throwable: Throwable? = null) {
        if (isEnabled) Log.e(TAG, "[Deeplink] ❌ $message", throwable)
    }
}
