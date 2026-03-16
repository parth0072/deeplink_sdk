package com.deeplink.sdk

import android.content.ContentProvider
import android.content.ContentValues
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri

/**
 * ContentProvider-based auto-initializer for the Deeplink SDK.
 *
 * This is the same pattern Branch.io uses: Android guarantees ContentProviders
 * run before `Application.onCreate()`, so the SDK is ready before any app code runs.
 *
 * ## Usage (zero-code setup)
 *
 * Add to your app's `AndroidManifest.xml`:
 * ```xml
 * <meta-data android:name="DeeplinkAPIKey" android:value="your-api-key" />
 * <meta-data android:name="DeeplinkDomain"  android:value="dl.yourapp.com" />
 * ```
 *
 * That's it — no `Application.onCreate()` code needed.
 *
 * ## Manual setup (if you need to call setDebug first)
 *
 * Disable the provider in your app's manifest:
 * ```xml
 * <provider
 *     android:name="com.deeplink.sdk.DeeplinkInitProvider"
 *     android:authorities="${applicationId}.deeplinkprovider"
 *     android:enabled="false"
 *     tools:replace="android:enabled" />
 * ```
 *
 * Then in `Application.onCreate()`:
 * ```kotlin
 * DeeplinkSDK.setDebug(BuildConfig.DEBUG)
 * DeeplinkSDK.configure(context, apiKey = "...", domain = "...")
 * ```
 */
internal class DeeplinkInitProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        val ctx = context ?: return false
        try {
            val ai = ctx.packageManager.getApplicationInfo(
                ctx.packageName, PackageManager.GET_META_DATA
            )
            val meta = ai.metaData ?: return false
            val apiKey = meta.getString("DeeplinkAPIKey")
            val domain = meta.getString("DeeplinkDomain")

            if (!apiKey.isNullOrBlank() && !domain.isNullOrBlank()) {
                DeeplinkSDK.configure(ctx, apiKey = apiKey, domain = domain)
                DeeplinkLogger.log("DeeplinkInitProvider — auto-configured from manifest meta-data")
            } else {
                DeeplinkLogger.log("DeeplinkInitProvider — DeeplinkAPIKey/DeeplinkDomain not found in manifest; call DeeplinkSDK.configure() manually")
            }
        } catch (e: Exception) {
            DeeplinkLogger.error("DeeplinkInitProvider.onCreate failed", e)
        }
        return true
    }

    // ContentProvider stubs — not used for data access
    override fun query(uri: Uri, p: Array<out String>?, s: String?, sa: Array<out String>?, so: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, s: String?, sa: Array<out String>?): Int = 0
    override fun update(uri: Uri, v: ContentValues?, s: String?, sa: Array<out String>?): Int = 0
}
