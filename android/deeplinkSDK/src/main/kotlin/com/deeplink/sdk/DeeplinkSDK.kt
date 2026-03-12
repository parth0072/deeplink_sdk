package com.deeplink.sdk

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import java.util.Locale
import java.util.TimeZone

/**
 * Main entry point for the Deeplink SDK.
 *
 * **Setup (Application.onCreate):**
 * ```kotlin
 * DeeplinkSDK.configure(context, apiKey = "your-api-key", domain = "dl.yourapp.com")
 * ```
 *
 * **Handle App Link / intent (Activity.onCreate):**
 * ```kotlin
 * DeeplinkSDK.handleIntent(intent) { link ->
 *     link?.let { navigateTo(it.pathSegments.firstOrNull()) }
 * }
 * ```
 *
 * **Deferred deep link (first launch):**
 * ```kotlin
 * DeeplinkSDK.getInitData { data ->
 *     data?.androidUrl?.let { openDeepLink(it) }
 * }
 * ```
 */
object DeeplinkSDK {

    private const val PREFS_NAME = "deeplink_sdk"
    private const val PREF_INIT_FETCHED = "init_fetched"
    private const val PREF_SESSION_ID = "session_id"

    private var config: DeeplinkConfig? = null
    private var linkHandler: LinkHandler? = null
    private var appContext: Context? = null

    /**
     * Configure the SDK. Call once in [android.app.Application.onCreate].
     */
    fun configure(context: Context, apiKey: String, domain: String) {
        val cfg = DeeplinkConfig(apiKey = apiKey, domain = domain)
        config = cfg
        linkHandler = LinkHandler(cfg)
        appContext = context.applicationContext
    }

    /**
     * Handle an incoming [Intent] from an App Link or custom URL scheme.
     * @param callback Invoked with the parsed [IncomingLink], or null if unrecognised.
     */
    fun handleIntent(intent: Intent, callback: ((IncomingLink?) -> Unit)? = null): IncomingLink? {
        val handler = requireHandler()
        val link = handler.handleIntent(intent)
        callback?.invoke(link)
        return link
    }

    /**
     * Fetch deferred deep link data from the server.
     * Call once after the user completes onboarding on first launch.
     * Subsequent calls are no-ops unless [force] is true.
     *
     * @param callback Invoked on the **main thread** with [DeeplinkData] or null.
     */
    fun getInitData(force: Boolean = false, callback: (DeeplinkData?) -> Unit) {
        val cfg = requireConfig()
        val ctx = appContext ?: error("DeeplinkSDK not configured")
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val alreadyFetched = prefs.getBoolean(PREF_INIT_FETCHED, false)
        if (alreadyFetched && !force) {
            callback(null)
            return
        }

        ApiClient.fetchInitData(cfg, collectDeviceSignals(ctx)) { data ->
            if (data != null) {
                prefs.edit().putBoolean(PREF_INIT_FETCHED, true).apply()
            }
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                callback(data)
            }
        }
    }

    /**
     * Create a deep link programmatically.
     *
     * The [params] map is stored as link metadata and returned by [getInitData] when the
     * recipient opens the app, letting you pass arbitrary data through the link.
     *
     * ```kotlin
     * DeeplinkSDK.createLink(
     *     destination = "https://yourapp.com/product/123",
     *     params = mapOf("product_id" to "123", "promo" to "launch10"),
     *     utmCampaign = "launch"
     * ) { result ->
     *     result?.let { shareLink(it.url) }
     * }
     * ```
     *
     * @param callback Invoked on the **main thread** with [CreatedLink] or null on failure.
     */
    fun createLink(
        destination: String,
        params: Map<String, String> = emptyMap(),
        iosUrl: String? = null,
        androidUrl: String? = null,
        alias: String? = null,
        title: String? = null,
        description: String? = null,
        utmSource: String? = null,
        utmMedium: String? = null,
        utmCampaign: String? = null,
        expiresAt: String? = null,
        callback: (CreatedLink?) -> Unit,
    ) {
        val cfg = requireConfig()
        ApiClient.createLink(
            config = cfg,
            destination = destination,
            params = params,
            iosUrl = iosUrl,
            androidUrl = androidUrl,
            alias = alias,
            title = title,
            description = description,
            utmSource = utmSource,
            utmMedium = utmMedium,
            utmCampaign = utmCampaign,
            expiresAt = expiresAt,
        ) { result ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                callback(result)
            }
        }
    }

    /**
     * Record an impression for a link displayed in-app.
     *
     * Opening the link URL already records an impression automatically.
     * Call this only when you show a deep link inside a banner or share sheet
     * without the user actually opening the link URL.
     *
     * ```kotlin
     * DeeplinkSDK.recordImpression("summer-sale")
     * ```
     */
    fun recordImpression(alias: String, callback: ((Boolean) -> Unit)? = null) {
        val cfg = requireConfig()
        ApiClient.recordImpression(cfg, alias, callback)
    }

    /**
     * Track a custom event with optional properties.
     *
     * ```kotlin
     * DeeplinkSDK.track("purchase", mapOf("amount" to 49.99, "currency" to "USD"))
     * ```
     *
     * @param name Event name (e.g. "signup", "purchase").
     * @param properties Optional map of event properties (String, Int, Double, Boolean values).
     */
    fun track(name: String, properties: Map<String, Any> = emptyMap()) {
        val cfg = requireConfig()
        val sessionId = currentSessionId()
        ApiClient.trackEvent(cfg, name, properties, sessionId)
    }

    /** Reset the "already fetched" flag (useful for testing). */
    fun resetInitState() {
        val ctx = appContext ?: return
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().remove(PREF_INIT_FETCHED).apply()
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun requireConfig(): DeeplinkConfig =
        config ?: error("DeeplinkSDK.configure() must be called before using the SDK")

    private fun requireHandler(): LinkHandler =
        linkHandler ?: error("DeeplinkSDK.configure() must be called before using the SDK")

    private fun currentSessionId(): String {
        val ctx = appContext ?: error("DeeplinkSDK not configured")
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(PREF_SESSION_ID, null) ?: java.util.UUID.randomUUID().toString().also {
            prefs.edit().putString(PREF_SESSION_ID, it).apply()
        }
    }

    /**
     * Collects device signals for fingerprint matching.
     *
     * Includes:
     * - device_id: ANDROID_ID — stable per device + app signing key, no permission needed,
     *   resets only on factory reset. Used for deterministic matching on reinstall.
     * - Probabilistic signals: model, OS, screen res, timezone, language.
     */
    private fun collectDeviceSignals(ctx: Context): Map<String, String?> {
        return try {
            val dm = ctx.resources.displayMetrics
            val dpr = dm.density
            val w = (dm.widthPixels / dpr).toInt()
            val h = (dm.heightPixels / dpr).toInt()
            val dprStr = if (dpr == dpr.toLong().toFloat()) "${dpr.toLong()}" else "$dpr"

            // ANDROID_ID: unique per (device, app signing key). No permission required.
            // Stable across installs/reinstalls; resets only on factory reset.
            val androidId = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ANDROID_ID)

            mapOf(
                "device_id"    to androidId,
                "device_model" to Build.MODEL,
                "os_version"   to Build.VERSION.RELEASE,
                "screen_res"   to "${w}x${h}x${dprStr}",
                "timezone"     to TimeZone.getDefault().id,
                "language"     to Locale.getDefault().language,
            )
        } catch (_: Exception) {
            emptyMap()
        }
    }
}
