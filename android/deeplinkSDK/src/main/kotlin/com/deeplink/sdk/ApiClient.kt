package com.deeplink.sdk

import android.os.Build
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal object ApiClient {

    fun fetchInitData(
        config: DeeplinkConfig,
        deviceSignals: Map<String, String?> = emptyMap(),
        referrerClickId: String? = null,
        callback: (DeeplinkData?) -> Unit,
    ) {
        Thread {
            val body = JSONObject().apply {
                put("api_key", config.apiKey)
                put("user_agent", buildUserAgent())
                deviceSignals.forEach { (k, v) -> if (v != null) put(k, v) }
                if (referrerClickId != null) {
                    put("referrer_click_id", referrerClickId)
                    DeeplinkLogger.log("fetchInitData — referrer_click_id=$referrerClickId (deterministic)")
                }
            }
            DeeplinkLogger.log("fetchInitData → POST /sdk/init signals=${deviceSignals.keys}")
            val result = post(config, "/sdk/init", body, timeout = 10_000) { json ->
                val matched = json.optBoolean("matched", false)
                DeeplinkLogger.log("fetchInitData ← matched=$matched")
                if (!matched) return@post null
                val data = json.optJSONObject("data") ?: return@post null
                val meta = mutableMapOf<String, String>()
                data.optJSONObject("metadata")?.let { m ->
                    m.keys().forEach { k -> meta[k] = m.optString(k) }
                }
                DeeplinkData(
                    linkId         = data.getString("linkId"),
                    alias          = data.getString("alias"),
                    iosUrl         = data.optString("iosUrl").takeIf { it.isNotEmpty() },
                    androidUrl     = data.optString("androidUrl").takeIf { it.isNotEmpty() },
                    destinationUrl = data.getString("destinationUrl"),
                    utmSource      = data.optString("utmSource").takeIf { it.isNotEmpty() },
                    utmMedium      = data.optString("utmMedium").takeIf { it.isNotEmpty() },
                    utmCampaign    = data.optString("utmCampaign").takeIf { it.isNotEmpty() },
                    utmContent     = data.optString("utmContent").takeIf { it.isNotEmpty() },
                    utmTerm        = data.optString("utmTerm").takeIf { it.isNotEmpty() },
                    metadata       = meta,
                    creativeName   = data.optString("creativeName").takeIf { it.isNotEmpty() },
                    creativeId     = data.optString("creativeId").takeIf { it.isNotEmpty() },
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
        ogImage: String? = null,
        utmSource: String? = null,
        utmMedium: String? = null,
        utmCampaign: String? = null,
        utmContent: String? = null,
        utmTerm: String? = null,
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
                ogImage?.let     { put("og_image", it) }
                utmSource?.let   { put("utm_source", it) }
                utmMedium?.let   { put("utm_medium", it) }
                utmCampaign?.let { put("utm_campaign", it) }
                utmContent?.let  { put("utm_content", it) }
                utmTerm?.let     { put("utm_term", it) }
                expiresAt?.let   { put("expires_at", it) }
            }
            DeeplinkLogger.log("createLink → dest=$destination")
            val result = post(config, "/sdk/link", body) { json ->
                DeeplinkLogger.log("createLink ← url=${json.optString("url")}")
                CreatedLink(
                    url    = json.getString("url"),
                    alias  = json.getString("alias"),
                    linkId = json.getString("link_id"),
                )
            }
            callback(result)
        }.start()
    }

    fun fetchLinkData(config: DeeplinkConfig, alias: String, callback: (DeeplinkData?) -> Unit) {
        Thread {
            DeeplinkLogger.log("fetchLinkData → alias=$alias")
            val result = get(config, "/sdk/resolve/$alias") { json ->
                val matched = json.optBoolean("matched", false)
                if (!matched) return@get null
                val data = json.optJSONObject("data") ?: return@get null
                val meta = mutableMapOf<String, String>()
                data.optJSONObject("metadata")?.let { m ->
                    m.keys().forEach { k -> meta[k] = m.optString(k) }
                }
                DeeplinkData(
                    linkId         = data.getString("linkId"),
                    alias          = data.getString("alias"),
                    iosUrl         = data.optString("iosUrl").takeIf { it.isNotEmpty() },
                    androidUrl     = data.optString("androidUrl").takeIf { it.isNotEmpty() },
                    destinationUrl = data.getString("destinationUrl"),
                    utmSource      = data.optString("utmSource").takeIf { it.isNotEmpty() },
                    utmMedium      = data.optString("utmMedium").takeIf { it.isNotEmpty() },
                    utmCampaign    = data.optString("utmCampaign").takeIf { it.isNotEmpty() },
                    utmContent     = data.optString("utmContent").takeIf { it.isNotEmpty() },
                    utmTerm        = data.optString("utmTerm").takeIf { it.isNotEmpty() },
                    metadata       = meta,
                    creativeName   = data.optString("creativeName").takeIf { it.isNotEmpty() },
                    creativeId     = data.optString("creativeId").takeIf { it.isNotEmpty() },
                )
            }
            DeeplinkLogger.log("fetchLinkData ← metadata=${result?.metadata}")
            callback(result)
        }.start()
    }

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
            DeeplinkLogger.log("track '$name' props=$properties")
            post(config, "/api/events", body) { _: JSONObject -> null }
        }.start()
    }

    // MARK: - HTTP helper (synchronous — always call from a background thread)

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
        if (conn.responseCode !in 200..299) {
            DeeplinkLogger.error("POST $path returned ${conn.responseCode}")
            return null
        }
        parse(JSONObject(conn.inputStream.bufferedReader().readText()))
    } catch (e: Exception) {
        DeeplinkLogger.error("POST $path failed", e)
        null
    }

    private fun <T> get(
        config: DeeplinkConfig,
        path: String,
        timeout: Int = 10_000,
        parse: (JSONObject) -> T?,
    ): T? = try {
        val conn = (URL("${config.apiBaseUrl}$path?api_key=${config.apiKey}").openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = timeout
            readTimeout = timeout
        }
        if (conn.responseCode !in 200..299) {
            DeeplinkLogger.error("GET $path returned ${conn.responseCode}")
            return null
        }
        parse(JSONObject(conn.inputStream.bufferedReader().readText()))
    } catch (e: Exception) {
        DeeplinkLogger.error("GET $path failed", e)
        null
    }

    private fun buildUserAgent(): String =
        "DeeplinkSDK-Android/${Build.MODEL} Android/${Build.VERSION.RELEASE}"
}
