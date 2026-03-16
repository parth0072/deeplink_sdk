package com.deeplink.sdk

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import java.util.Locale
import java.util.TimeZone

/**
 * Main entry point for the Deeplink Android SDK.
 *
 * ## Quick Start
 *
 * **Option A — zero-code (recommended):**
 * Add to your app's `AndroidManifest.xml`:
 * ```xml
 * <meta-data android:name="DeeplinkAPIKey" android:value="your-api-key" />
 * <meta-data android:name="DeeplinkDomain"  android:value="dl.yourapp.com" />
 * ```
 * The [DeeplinkInitProvider] ContentProvider configures the SDK automatically.
 *
 * **Option B — manual (Application.onCreate):**
 * ```kotlin
 * DeeplinkSDK.setDebug(BuildConfig.DEBUG)
 * DeeplinkSDK.configure(context, apiKey = "your-api-key", domain = "dl.yourapp.com")
 * ```
 *
 * **Handle App Links / URI schemes (Activity.onCreate):**
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
 *
 * **First-install-only callback:**
 * ```kotlin
 * DeeplinkSDK.onFirstLaunch { data ->
 *     Analytics.track("install", mapOf("source" to (data?.utmSource ?: "organic")))
 * }
 * ```
 */
object DeeplinkSDK {

    private const val PREFS_NAME        = "deeplink_sdk"
    private const val PREF_INIT_FETCHED = "init_fetched"
    private const val PREF_FIRST_LAUNCH = "first_launch_done"
    private const val PREF_SESSION_ID   = "session_id"

    private var config: DeeplinkConfig? = null
    /** In-memory cache: alias → DeeplinkData. Populated by getInitData/onFirstLaunch. */
    private val linkDataCache = mutableMapOf<String, DeeplinkData>()
    private var linkHandler: LinkHandler? = null
    private var appContext: Context? = null

    // MARK: - Setup

    /**
     * Enable verbose logging to Logcat. Call this **before** [configure].
     *
     * Logs are tagged `DeeplinkSDK` and visible in Logcat with filter `[Deeplink]`.
     *
     * ```kotlin
     * DeeplinkSDK.setDebug(BuildConfig.DEBUG)
     * ```
     */
    fun setDebug(enabled: Boolean) {
        DeeplinkLogger.isEnabled = enabled
        DeeplinkLogger.log("Debug mode ${if (enabled) "enabled" else "disabled"}")
    }

    /**
     * Configure the SDK. Call once in [android.app.Application.onCreate] or use the
     * zero-code manifest meta-data approach via [DeeplinkInitProvider].
     */
    fun configure(context: Context, apiKey: String, domain: String) {
        val cfg = DeeplinkConfig(apiKey = apiKey, domain = domain)
        config = cfg
        linkHandler = LinkHandler(cfg)
        appContext = context.applicationContext
        DeeplinkLogger.log("configure — apiKey=${apiKey.take(8)}*** domain=$domain")
    }

    // MARK: - Deep Link Handling

    /**
     * Handle an incoming [Intent] from an App Link or custom URI scheme.
     * Call this from every Activity's `onCreate` and `onNewIntent`.
     *
     * @param callback Invoked with the parsed [IncomingLink], or null if unrecognised.
     */
    fun handleIntent(intent: Intent, callback: ((IncomingLink?) -> Unit)? = null): IncomingLink? {
        val handler = requireHandler()
        val link = handler.handleIntent(intent)
        callback?.invoke(link)
        return link
    }

    // MARK: - Attribution

    /**
     * Fetch deferred deep link data from the server.
     *
     * Call once after the user completes onboarding on first launch.
     * Subsequent calls are no-ops unless [force] is `true`.
     *
     * @param callback Invoked on the **main thread** with [DeeplinkData] or null.
     */
    fun getInitData(force: Boolean = false, callback: (DeeplinkData?) -> Unit) {
        val cfg = requireConfig()
        val ctx = appContext ?: error("DeeplinkSDK not configured")
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val alreadyFetched = prefs.getBoolean(PREF_INIT_FETCHED, false)
        if (alreadyFetched && !force) {
            DeeplinkLogger.log("getInitData — already fetched (use force=true to re-fetch)")
            callback(null)
            return
        }

        DeeplinkLogger.log("getInitData — fetching...")

        readInstallReferrer(ctx) { referrerClickId ->
            ApiClient.fetchInitData(cfg, collectDeviceSignals(ctx), referrerClickId) { data ->
                if (data != null) {
                    prefs.edit().putBoolean(PREF_INIT_FETCHED, true).apply()
                    linkDataCache[data.alias] = data
                    DeeplinkLogger.log("getInitData — matched alias=${data.alias}")
                } else {
                    DeeplinkLogger.log("getInitData — no match")
                }
                mainThread { callback(data) }
            }
        }
    }

    /**
     * Register a callback that fires **only on the very first app install**.
     *
     * Unlike [getInitData], this fires even when there is no deep link to route —
     * useful for onboarding flows, install event recording, or awarding install bonuses.
     *
     * Subsequent launches (including updates and reinstalls) will NOT trigger this.
     *
     * ```kotlin
     * DeeplinkSDK.onFirstLaunch { data ->
     *     Analytics.track("install", mapOf("utm_source" to (data?.utmSource ?: "organic")))
     *     data?.androidUrl?.let { navigateTo(it) }
     * }
     * ```
     */
    fun onFirstLaunch(callback: (DeeplinkData?) -> Unit) {
        val ctx = appContext ?: error("DeeplinkSDK not configured")
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(PREF_FIRST_LAUNCH, false)) {
            DeeplinkLogger.log("onFirstLaunch — already fired, skipping")
            return
        }
        prefs.edit().putBoolean(PREF_FIRST_LAUNCH, true).apply()
        DeeplinkLogger.log("onFirstLaunch — first install detected, fetching...")

        val cfg = requireConfig()
        readInstallReferrer(ctx) { referrerClickId ->
            ApiClient.fetchInitData(cfg, collectDeviceSignals(ctx), referrerClickId) { data ->
                if (data != null) {
                    prefs.edit().putBoolean(PREF_INIT_FETCHED, true).apply()
                }
                mainThread { callback(data) }
            }
        }
    }

    // MARK: - Link Creation

    /**
     * Create a deep link programmatically.
     *
     * The [params] map is returned by [getInitData] when the recipient opens the app,
     * letting you pass arbitrary data through the link.
     *
     * ```kotlin
     * DeeplinkSDK.createLink(
     *     destination = "https://yourapp.com/product/123",
     *     params = mapOf("product_id" to "123"),
     *     ogImage = "https://yourapp.com/images/product.jpg",
     *     utmSource = "instagram",
     *     utmCampaign = "summer_sale"
     * ) { result ->
     *     result?.let { share(it.url) }
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
        ogImage: String? = null,
        utmSource: String? = null,
        utmMedium: String? = null,
        utmCampaign: String? = null,
        utmContent: String? = null,
        utmTerm: String? = null,
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
            ogImage = ogImage,
            utmSource = utmSource,
            utmMedium = utmMedium,
            utmCampaign = utmCampaign,
            utmContent = utmContent,
            utmTerm = utmTerm,
            expiresAt = expiresAt,
        ) { result -> mainThread { callback(result) } }
    }

    /**
     * Fetch server-stored params/metadata for a link by alias.
     *
     * Call this after [handleIntent] returns an [IncomingLink] to retrieve the
     * `params` dictionary set at link creation time — these are NOT embedded in
     * the URL and require a server lookup.
     *
     * ```kotlin
     * DeeplinkSDK.handleIntent(intent) { link ->
     *     link?.pathSegments?.firstOrNull()?.let { alias ->
     *         DeeplinkSDK.getLinkData(alias) { data ->
     *             val productId = data?.metadata?.get("product_id")
     *         }
     *     }
     * }
     * ```
     *
     * @param callback Invoked on the **main thread** with [DeeplinkData] or null.
     */
    fun getLinkData(alias: String, callback: (DeeplinkData?) -> Unit) {
        // Return cached result if getInitData already fetched this alias — no extra network call
        linkDataCache[alias]?.let { cached ->
            DeeplinkLogger.log("getLinkData — cache hit for alias=$alias")
            mainThread { callback(cached) }
            return
        }
        ApiClient.fetchLinkData(requireConfig(), alias) { result ->
            if (result != null) linkDataCache[result.alias] = result
            mainThread { callback(result) }
        }
    }

    // MARK: - Impression & Events

    /**
     * Record an impression for a link displayed in-app (banner, share sheet, etc.).
     * Opening the link URL auto-records an impression; call this only for in-app displays.
     */
    fun recordImpression(alias: String, callback: ((Boolean) -> Unit)? = null) {
        ApiClient.recordImpression(requireConfig(), alias, callback)
    }

    /**
     * Track a custom event.
     *
     * ```kotlin
     * DeeplinkSDK.track("purchase", mapOf("amount" to 49.99, "currency" to "USD"))
     * ```
     */
    fun track(name: String, properties: Map<String, Any> = emptyMap()) {
        ApiClient.trackEvent(requireConfig(), name, properties, currentSessionId())
    }

    /** Reset init/first-launch flags (useful for testing). */
    fun resetInitState() {
        val ctx = appContext ?: return
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(PREF_INIT_FETCHED)
            .remove(PREF_FIRST_LAUNCH)
            .apply()
        DeeplinkLogger.log("resetInitState — flags cleared")
    }

    // MARK: - Helpers

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

    private fun mainThread(block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }

    /**
     * Reads the Play Store install referrer to extract our fingerprint click ID.
     *
     * When we redirect an Android user to the Play Store we append:
     *   `&referrer=deeplink_click_id%3D{fingerprintId}`
     *
     * The Play Store preserves this string and delivers it via [InstallReferrerClient]
     * on first launch — enabling 100% deterministic matching with no permissions.
     */
    private fun readInstallReferrer(ctx: Context, callback: (String?) -> Unit) {
        try {
            val client = InstallReferrerClient.newBuilder(ctx).build()
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        try {
                            val referrer = client.installReferrer.installReferrer
                            client.endConnection()
                            val clickId = parseClickId(referrer)
                            DeeplinkLogger.log("installReferrer — raw='$referrer' clickId=$clickId")
                            callback(clickId)
                        } catch (e: Exception) {
                            client.endConnection()
                            DeeplinkLogger.error("installReferrer read failed", e)
                            callback(null)
                        }
                    } else {
                        client.endConnection()
                        DeeplinkLogger.log("installReferrer — response code $responseCode (no referrer)")
                        callback(null)
                    }
                }
                override fun onInstallReferrerServiceDisconnected() { callback(null) }
            })
        } catch (e: Exception) {
            DeeplinkLogger.error("InstallReferrerClient.newBuilder failed", e)
            callback(null)
        }
    }

    private fun parseClickId(referrer: String?): String? {
        if (referrer.isNullOrBlank()) return null
        return referrer.split('&')
            .firstOrNull { it.startsWith("deeplink_click_id=") }
            ?.removePrefix("deeplink_click_id=")
            ?.takeIf { it.isNotBlank() }
    }

    /**
     * Collects device signals for fingerprint matching.
     *
     * - `device_id`: ANDROID_ID — stable per (device, signing key), no permission needed.
     * - Probabilistic signals: model, OS, screen, timezone, language.
     */
    private fun collectDeviceSignals(ctx: Context): Map<String, String?> {
        return try {
            val dm = ctx.resources.displayMetrics
            val dpr = dm.density
            val w = (dm.widthPixels / dpr).toInt()
            val h = (dm.heightPixels / dpr).toInt()
            val dprStr = if (dpr == dpr.toLong().toFloat()) "${dpr.toLong()}" else "$dpr"
            val androidId = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ANDROID_ID)
            val signals = mapOf(
                "device_id"    to androidId,
                "device_model" to Build.MODEL,
                "os_version"   to Build.VERSION.RELEASE,
                "screen_res"   to "${w}x${h}x${dprStr}",
                "timezone"     to TimeZone.getDefault().id,
                "language"     to Locale.getDefault().language,
            )
            DeeplinkLogger.log("collectDeviceSignals — ${signals.entries.joinToString { "${it.key}=${it.value}" }}")
            signals
        } catch (e: Exception) {
            DeeplinkLogger.error("collectDeviceSignals failed", e)
            emptyMap()
        }
    }
}
