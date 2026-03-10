# Deeplink Android SDK

Native Kotlin SDK for deferred deep linking, link creation, and event tracking on Android.

← [Back to main SDK docs](../README.md)

---

## Requirements

| | Minimum |
|-|---------|
| Android API | 21+ (Android 5.0) |
| Kotlin | 1.8+ |

---

## Installation

### 1. Include the module

In `settings.gradle`:

```groovy
include ':deeplinkSDK'
project(':deeplinkSDK').projectDir = file('path/to/deeplink_sdk/android/deeplinkSDK')
```

### 2. Add the dependency

In your app's `build.gradle`:

```groovy
dependencies {
    implementation project(':deeplinkSDK')
}
```

---

## Setup

Call `configure` once in your `Application.onCreate()` — before any Activity starts.

```kotlin
import com.deeplink.sdk.DeeplinkSDK

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DeeplinkSDK.configure(
            context = this,
            apiKey  = "your-api-key",
            domain  = "https://dl.yourapp.com"
        )
    }
}
```

Register your `Application` class in `AndroidManifest.xml`:

```xml
<application android:name=".MyApplication" ...>
```

---

## Deferred Deep Linking

Fetch the deep link that originally brought the user to install your app. Call once after onboarding completes.

```kotlin
DeeplinkSDK.getInitData { data ->
    data ?: return@getInitData
    // data.destinationUrl  — fallback web URL
    // data.androidUrl      — Android-specific deep link (myapp://...)
    // data.metadata        — Map<String, String> custom key-value pairs
    // data.utmCampaign     — UTM campaign
    // data.creativeName    — creative name (if set on the link)
    openDeepLink(data.androidUrl ?: data.destinationUrl)
}

// Force re-fetch (e.g. during testing)
DeeplinkSDK.getInitData(force = true) { data -> ... }

// Reset the one-time guard
DeeplinkSDK.resetInitState()
```

---

## Android App Links

Handle links when the app is already installed.

**`AndroidManifest.xml`:**

```xml
<activity android:name=".MainActivity">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="dl.yourapp.com" />
    </intent-filter>
</activity>
```

**`MainActivity.kt`:**

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    DeeplinkSDK.handleIntent(intent) { link ->
        link ?: return@handleIntent
        // link.pathSegments — listOf("product", "123")
        // link.params       — mapOf("ref" to "email")
    }
}
```

**Enable App Links:**
1. Host the `assetlinks.json` file — the URL is shown in Admin → Settings → Android
2. Add your SHA-256 certificate fingerprint in Admin → Apps → your app

---

## Create Links

Generate short deep links from within the app.

```kotlin
DeeplinkSDK.createLink(
    destination = "https://yourapp.com/product/123",
    params      = mapOf("product_id" to "123", "promo" to "launch10"),
    iosUrl      = "myapp://product/123",
    androidUrl  = "myapp://product/123",
    title       = "Check this out",
    utmSource   = "share",
    utmCampaign = "referral"
) { result ->
    result ?: return@createLink
    // result.url   — "https://dl.yourapp.com/abc123"
    // result.alias — "abc123"
    shareLink(result.url)
}
```

---

## Event Tracking

Track custom events for funnel and cohort analysis.

```kotlin
// Basic
DeeplinkSDK.track("signup")

// With properties
DeeplinkSDK.track("purchase", mapOf(
    "amount"   to 49.99,
    "currency" to "USD",
    "item_id"  to "sku-123"
))

DeeplinkSDK.track("button_tapped", mapOf(
    "screen" to "home",
    "button" to "cta"
))
```

View events in Admin → Funnels and Admin → Cohorts.

---

## Sample App

A full Jetpack Compose sample app is at [`samples/android-sample/`](../samples/android-sample/).

Open `samples/android-sample/` in Android Studio — Gradle will pull in the `:deeplinkSDK` module automatically.

Demonstrates: configure, getInitData, handleIntent, createLink, track, resetInitState.
