package com.deeplink.sdk

import android.os.Build
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal object ApiClient {

    // MARK: - SDK Endpoints

    /**
     * @param deviceSignals Optional device fingerprint signals to improve deferred
     *   deep link matching accuracy. Keys: device_model, os_version, screen_res,
     *   timezone, language.
     */
    fun fetchInitData(
        config: DeeplinkConfig,
        deviceSignals: Map<String, String?> = emptyMap(),
        callback: (DeeplinkData?) -> Unit,
    ) {
        Thread {
            val body = JSONObject().apply {
                put("api_key", config.apiKey)
                put("user_agent", buildUserAgent())
                deviceSignals.forEach { (k, v) -> if (v != null) put(k, v) }
            }
            val result = post(config, "/sdk/init", body, timeout = 10_000) { json ->
                if (!json.optBoolean("matched", false)) return@post null
                val data = json.optJSONObject("data") ?: return@post null
                val meta = mutableMapOf<String, String>()
                data.optJSONObject("metadata")?.let { m ->
                    m.keys().forEach { k -> meta[k] = m.optString(k) }
                }
                DeeplinkData(
                    linkId       = data.getString("linkId"),
                    alias        = data.getString("alias"),
                    iosUrl       = data.optString("iosUrl").takeIf { it.isNotEmpty() },
                    androidUrl   = data.optString("androidUrl").takeIf { it.isNotEmpty() },
                    destinationUrl = data.getString("destinationUrl"),
                    utmSource    = data.optString("utmSource").takeIf { it.isNotEmpty() },
                    utmMedium    = data.optString("utmMedium").takeIf { it.isNotEmpty() },
                    utmCampaign  = data.optString("utmCampaign").takeIf { it.isNotEmpty() },
                    utmContent   = data.optString("utmContent").takeIf { it.isNotEmpty() },
                    utmTerm      = data.optString("utmTerm").takeIf { it.isNotEmpty() },
                    metadata     = meta,
                    creativeName = data.optString("creativeName").takeIf { it.isNotEmpty() },
                    creativeId   = data.optString("creativeId").takeIf { it.isNotEmpty() },
                )
            }
            callback(result)
        }.start()
    }

    fun createLink(
        config: DeeplinkConfig,
        destination: String,
        params: Map<String, String>,
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
        Thread {
            val body = JSONObject().apply {
                put("api_key", config.apiKey)
                put("destination_url", destination)
                if (params.isNotEmpty()) put("params", JSONObject(params))
                iosUrl?.let      { put("ios_url", it) }
                androidUrl?.let  { put("android_url", it) }
                alias?.let       { put("alias", it) }
                title?.let       { put("title", it) }
                description?.let { put("description", it) }
                utmSource?.let   { put("utm_source", it) }
                utmMedium?.let   { put("utm_medium", it) }
                utmCampaign?.let { put("utm_campaign", it) }
                expiresAt?.let   { put("expires_at", it) }
            }
            val result = post(config, "/sdk/link", body) { json ->
                CreatedLink(
                    url    = json.getString("url"),
                    alias  = json.getString("alias"),
                    linkId = json.getString("link_id"),
                )
            }
            callback(result)
        }.start()
    }

    /**
     * Record an impression for a link displayed in-app. Fire-and-forget.
     * Opening the link URL already auto-records an impression; call this only
     * when you show a link inside a banner or share sheet without the user opening it.
     */
    fun recordImpression(config: DeeplinkConfig, alias: String, callback: ((Boolean) -> Unit)? = null) {
        Thread {
            val body = JSONObject().apply {
                put("api_key", config.apiKey)
                put("link_alias", alias)
                put("platform", "android")
            }
            post(config, "/api/impressions", body) { _: JSONObject -> null }
            android.os.Handler(android.os.Looper.getMainLooper()).post { callback?.invoke(true) }
        }.start()
    }

    fun trackEvent(config: DeeplinkConfig, name: String, properties: Map<String, Any>, sessionId: String) {
        Thread {
            val body = JSONObject().apply {
                put("api_key", config.apiKey)
                put("name", name)
                put("session_id", sessionId)
                if (properties.isNotEmpty()) put("properties", JSONObject(properties))
            }
            post(config, "/api/events", body) { _: JSONObject -> null }
        }.start()
    }

    // MARK: - Common HTTP helper (synchronous — always call from a background thread)

    private fun <T> post(
        config: DeeplinkConfig,
        path: String,
        body: JSONObject,
        timeout: Int = 15_000,
        parse: (JSONObject) -> T?,
    ): T? = try {
        val conn = (URL("${config.apiBaseUrl}$path").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            setRequestProperty("Content-Type", "application/json")
            doOutput = true
            connectTimeout = timeout
            readTimeout = timeout
        }
        conn.outputStream.use { it.write(body.toString().toByteArray()) }
        if (conn.responseCode !in 200..299) return null
        parse(JSONObject(conn.inputStream.bufferedReader().readText()))
    } catch (_: Exception) { null }

    // MARK: - Helpers

    private fun buildUserAgent(): String =
        "DeeplinkSDK-Android/${Build.MODEL} Android/${Build.VERSION.RELEASE}"
}
