package com.deeplink.sample

import android.app.Application
import android.util.Log
import com.deeplink.sdk.DeeplinkSDK

class SampleApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // ── Step 1: Configure the SDK ─────────────────────────────────────────
        // Call once in Application.onCreate(). Replace with your API key and domain.
        DeeplinkSDK.configure(
            context = this,
            apiKey  = "7f9d682990f7b0d1502906357a35cd5f886293f8cf2377d3",
            domain  = "https://deeplinkbe-production-5e4b.up.railway.app",
        )

        // ── Step 2: Fetch deferred deep link on first install ─────────────────
        // Matches device fingerprint to the click that led the user to install.
        // Call once after onboarding completes in production.
        DeeplinkSDK.getInitData { data ->
            if (data != null) {
                Log.d("Deeplink", "Matched install!")
                Log.d("Deeplink", "  destination : ${data.destinationUrl}")
                Log.d("Deeplink", "  androidUrl  : ${data.androidUrl}")
                Log.d("Deeplink", "  metadata    : ${data.metadata}")
                Log.d("Deeplink", "  utmCampaign : ${data.utmCampaign}")
                // TODO: Navigate to the deep-linked screen
            } else {
                Log.d("Deeplink", "No deferred deep link found.")
            }
        }
    }
}
