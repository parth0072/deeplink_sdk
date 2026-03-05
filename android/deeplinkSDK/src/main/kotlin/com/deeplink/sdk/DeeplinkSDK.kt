package com.deeplink.sdk

import android.content.Context
import android.content.Intent

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

        ApiClient.fetchInitData(cfg) { data ->
            if (data != null) {
                prefs.edit().putBoolean(PREF_INIT_FETCHED, true).apply()
            }
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                callback(data)
            }
        }
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
}
