package com.deeplink.sdk

/**
 * Data returned by the SDK when a deep link is resolved.
 */
data class DeeplinkData(
    val linkId: String,
    val alias: String,
    val iosUrl: String?,
    val androidUrl: String?,
    val destinationUrl: String,
    val utmSource: String?,
    val utmMedium: String?,
    val utmCampaign: String?,
    val utmContent: String?,
    val utmTerm: String?,
    /** Custom key-value metadata set on the link in the dashboard. */
    val metadata: Map<String, String> = emptyMap(),
    /** Creative name for attribution reporting. */
    val creativeName: String? = null,
    /** Creative ID for attribution reporting. */
    val creativeId: String? = null,
)

/**
 * Result returned after successfully creating a deep link via the SDK.
 * @property url Full short URL (e.g. `https://dl.yourapp.com/abc123`).
 * @property alias Short alias component (e.g. `abc123`).
 * @property linkId Server-assigned link UUID.
 */
data class CreatedLink(
    val url: String,
    val alias: String,
    val linkId: String,
)

/** Parsed incoming Android App Link or custom scheme URL. */
data class IncomingLink(
    val url: android.net.Uri,
    val pathSegments: List<String>,
    val params: Map<String, String>,
)
