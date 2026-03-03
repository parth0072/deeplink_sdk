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
)

/** Parsed incoming Android App Link or custom scheme URL. */
data class IncomingLink(
    val url: android.net.Uri,
    val pathSegments: List<String>,
    val params: Map<String, String>,
)
