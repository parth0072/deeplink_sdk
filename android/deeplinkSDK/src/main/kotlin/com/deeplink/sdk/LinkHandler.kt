package com.deeplink.sdk

import android.content.Intent
import android.net.Uri

internal class LinkHandler(private val config: DeeplinkConfig) {

    fun canHandle(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase() ?: return false
        // Custom URI scheme (e.g. myapp://) — always a deep link
        if (scheme != "http" && scheme != "https") {
            DeeplinkLogger.log("canHandle — custom scheme: $uri")
            return true
        }
        // App Link — host must match our configured domain
        val isAppLink = uri.host == config.domain
        if (isAppLink) DeeplinkLogger.log("canHandle — App Link: $uri")
        return isAppLink
    }

    fun handle(uri: Uri): IncomingLink? {
        if (!canHandle(uri)) return null
        val segments = uri.pathSegments ?: emptyList()
        val params = uri.queryParameterNames
            .associateWith { uri.getQueryParameter(it) ?: "" }
        DeeplinkLogger.log("handle — path=${segments}, params=$params")
        return IncomingLink(url = uri, pathSegments = segments, params = params)
    }

    fun handleIntent(intent: Intent): IncomingLink? {
        val uri = intent.data ?: return null
        return handle(uri)
    }
}
