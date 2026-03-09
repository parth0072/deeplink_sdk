package com.deeplink.sdk

/**
 * Configuration for the Deeplink SDK.
 *
 * @param apiKey Your app API key from the Deeplink admin panel.
 * @param domain The base domain of your Deeplink server (e.g. "dl.yourapp.com").
 */
internal data class DeeplinkConfig(
    val apiKey: String,
    val domain: String,
) {
    val apiBaseUrl: String get() = "https://$domain"
}
