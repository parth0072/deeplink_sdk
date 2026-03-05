package com.deeplink.sdk

import android.os.Build
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

internal object ApiClient {

    fun fetchInitData(config: DeeplinkConfig, callback: (DeeplinkData?) -> Unit) {
        Thread {
            try {
                val url = URL("${config.apiBaseUrl}/sdk/init")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 10_000
                conn.readTimeout = 10_000

                val body = JSONObject().apply {
                    put("api_key", config.apiKey)
                    put("user_agent", buildUserAgent())
                }.toString()

                OutputStreamWriter(conn.outputStream).use { it.write(body) }

                if (conn.responseCode !in 200..299) {
                    callback(null)
                    return@Thread
                }

                val json = conn.inputStream.bufferedReader().readText()
                val root = JSONObject(json)

                if (!root.optBoolean("matched", false)) {
                    callback(null)
                    return@Thread
                }

                val data = root.optJSONObject("data") ?: run {
                    callback(null)
                    return@Thread
                }

                val metadataMap = mutableMapOf<String, String>()
                data.optJSONObject("metadata")?.let { meta ->
                    meta.keys().forEach { key -> metadataMap[key] = meta.optString(key) }
                }

                callback(
                    DeeplinkData(
                        linkId = data.getString("linkId"),
                        alias = data.getString("alias"),
                        iosUrl = data.optString("iosUrl").takeIf { it.isNotEmpty() },
                        androidUrl = data.optString("androidUrl").takeIf { it.isNotEmpty() },
                        destinationUrl = data.getString("destinationUrl"),
                        utmSource = data.optString("utmSource").takeIf { it.isNotEmpty() },
                        utmMedium = data.optString("utmMedium").takeIf { it.isNotEmpty() },
                        utmCampaign = data.optString("utmCampaign").takeIf { it.isNotEmpty() },
                        utmContent = data.optString("utmContent").takeIf { it.isNotEmpty() },
                        utmTerm = data.optString("utmTerm").takeIf { it.isNotEmpty() },
                        metadata = metadataMap,
                        creativeName = data.optString("creativeName").takeIf { it.isNotEmpty() },
                        creativeId = data.optString("creativeId").takeIf { it.isNotEmpty() },
                    )
                )
            } catch (e: Exception) {
                callback(null)
            }
        }.start()
    }

    fun trackEvent(config: DeeplinkConfig, name: String, properties: Map<String, Any>, sessionId: String) {
        Thread {
            try {
                val url = URL("${config.apiBaseUrl}/api/events")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 10_000
                conn.readTimeout = 10_000

                val propsJson = JSONObject(properties)
                val body = JSONObject().apply {
                    put("api_key", config.apiKey)
                    put("name", name)
                    put("session_id", sessionId)
                    if (properties.isNotEmpty()) put("properties", propsJson)
                }.toString()

                OutputStreamWriter(conn.outputStream).use { it.write(body) }
                conn.responseCode // trigger the request
            } catch (_: Exception) { }
        }.start()
    }

    private fun buildUserAgent(): String {
        return "DeeplinkSDK-Android/${Build.MODEL} Android/${Build.VERSION.RELEASE}"
    }
}
