# Deeplink Android SDK

Kotlin library for deferred deep linking, Android App Links, and mobile attribution — self-hosted, no third-party attribution SDKs required.

## Requirements

- Android API 21+ (Android 5.0)
- Kotlin 1.8+
- Google Play Services (for Play Install Referrer)

## Installation

### Gradle (JitPack)

Add JitPack to your root `settings.gradle`:
```groovy
dependencyResolutionManagement {
    repositories {
        maven { url 'https://jitpack.io' }
    }
}
```

Add the dependency:
```groovy
dependencies {
    implementation 'com.github.parth0072:deeplink-android-sdk:1.0.0'
}
```

### Manual (AAR)

Download the latest AAR from [Releases](https://github.com/parth0072/deeplink-android-sdk/releases) and add it to your `libs/` folder.

## Quick Start

### Option A — Zero-code setup (recommended)

Add to your app's `AndroidManifest.xml`:
```xml
<application ...>
    <meta-data android:name="DeeplinkAPIKey" android:value="your-api-key" />
    <meta-data android:name="DeeplinkDomain"  android:value="dl.yourapp.com" />
</application>
```

The `DeeplinkInitProvider` ContentProvider auto-configures the SDK before your `Application.onCreate()` runs — no code needed.

### Option B — Manual setup

Disable the auto-init provider and configure manually:
```xml
<!-- AndroidManifest.xml -->
<provider
    android:name="com.deeplink.sdk.DeeplinkInitProvider"
    android:authorities="${applicationId}.deeplinkprovider"
    android:enabled="false"
    tools:replace="android:enabled" />
```

```kotlin
// Application.onCreate()
DeeplinkSDK.setDebug(BuildConfig.DEBUG)
DeeplinkSDK.configure(this, apiKey = "your-api-key", domain = "dl.yourapp.com")
```

### 2. Handle App Links / URI Schemes

```kotlin
// Activity.onCreate() and onNewIntent()
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    DeeplinkSDK.handleIntent(intent) { link ->
        link?.let { navigateTo(it.pathSegments.firstOrNull()) }
    }
}

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    DeeplinkSDK.handleIntent(intent) { link ->
        link?.let { navigateTo(it.pathSegments.firstOrNull()) }
    }
}
```

### 3. Deferred Deep Link

```kotlin
// Called once on first launch after onboarding
DeeplinkSDK.getInitData { data ->
    data ?: return@getInitData
    println("Campaign: ${data.utmCampaign}")
    navigateTo(data.androidUrl ?: data.destinationUrl)
}
```

### 4. First Install Callback

```kotlin
// Fires ONLY on the very first install — even with no deep link to route
DeeplinkSDK.onFirstLaunch { data ->
    analytics.track("install", mapOf(
        "source" to (data?.utmSource ?: "organic"),
        "campaign" to (data?.utmCampaign ?: "")
    ))
    data?.androidUrl?.let { navigateTo(it) }
}
```

### 5. Create Links

```kotlin
DeeplinkSDK.createLink(
    destination = "https://yourapp.com/product/123",
    params = mapOf("product_id" to "123", "promo" to "launch10"),
    utmSource = "twitter",
    utmCampaign = "launch"
) { result ->
    result?.let { shareLink(it.url) }  // e.g. "https://dl.yourapp.com/abc123"
}
```

### 6. Event Tracking

```kotlin
DeeplinkSDK.track("purchase", mapOf("amount" to 49.99, "currency" to "USD"))
DeeplinkSDK.track("signup")
```

## How Attribution Works

| Scenario | Method | Accuracy |
|---|---|---|
| Play Store install | Play Install Referrer (click ID) | **100% deterministic** |
| Reinstall (same device) | ANDROID_ID matching | ~95+ pts (deterministic) |
| Different network | Model + screen + OS + ANDROID_ID | ~55–70 pts |
| Same WiFi, same model | Screen res + OS version | ~65 pts |

**Play Install Referrer** is the primary matching method — when the user is redirected to the Play Store, the backend embeds a fingerprint click ID in the referrer URL. The Play Store preserves this and delivers it via `InstallReferrerClient` on first launch, with no permissions required.

**ANDROID_ID** is the fallback for sideloaded APKs or when the referrer isn't available. It's stable per (device, app signing key) and resets only on factory reset.

## Android App Links Setup

1. Add your domain to your `AndroidManifest.xml` intent filter:
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="dl.yourapp.com" />
</intent-filter>
```
2. Your backend automatically serves `/.well-known/assetlinks.json`

## Debug Mode

```kotlin
DeeplinkSDK.setDebug(BuildConfig.DEBUG)
```

Logs appear in Logcat filtered by tag `DeeplinkSDK` or text `[Deeplink]`.

## ProGuard / R8

Consumer rules are included automatically. No manual configuration needed.

## License

MIT — see [LICENSE](LICENSE)
