package com.deeplink.sdk

import android.content.Intent
import android.net.Uri

internal class LinkHandler(private val config: DeeplinkConfig) {

    fun canHandle(uri: Uri): Boolean {
        val host = uri.host ?: return false
        return host == config.domain
    }

    fun handle(uri: Uri): IncomingLink? {
        if (!canHandle(uri)) return null

        val segments = uri.pathSegments ?: emptyList()
        val params = uri.queryParameterNames
            .associateWith { uri.getQueryParameter(it) ?: "" }

        return IncomingLink(url = uri, pathSegments = segments, params = params)
    }

    fun handleIntent(intent: Intent): IncomingLink? {
        val uri = intent.data ?: return null
        return handle(uri)
    }
}
