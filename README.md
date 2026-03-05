# Deeplink AI — Mobile SDKs

Native mobile SDKs for the Deeplink AI platform. Handles deferred deep linking, click attribution, and custom event tracking.

---

## Repository Structure

```
├── ios/                  # iOS SDK (Swift Package)
│   ├── Package.swift
│   └── Sources/
│       └── DeeplinkSDK/
│           ├── DeeplinkSDK.swift     # Main entry point
│           ├── APIClient.swift       # HTTP client
│           ├── DeeplinkData.swift    # Data models
│           ├── DeeplinkConfig.swift  # Config
│           ├── LinkHandler.swift     # URL parsing
│           └── IncomingLink.swift    # Parsed link model
└── android/              # Android SDK (Kotlin Library)
    ├── build.gradle
    └── deeplinkSDK/
        └── src/main/kotlin/com/deeplink/sdk/
            ├── DeeplinkSDK.kt        # Main entry point
            ├── ApiClient.kt          # HTTP client
            ├── DeeplinkData.kt       # Data models
            ├── DeeplinkConfig.kt     # Config
            ├── LinkHandler.kt        # Intent parsing
            └── IncomingLink.kt       # Parsed link model
```

---

## iOS SDK

### Requirements
- iOS 14+
- Swift 5.7+
- Xcode 14+

### Installation

#### Swift Package Manager

In Xcode: **File → Add Package Dependencies** and enter the repository URL, or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/parth0072/deeplink_sdk.git", from: "1.0.0")
]
```

### Setup

```swift
// AppDelegate.swift or @main App struct
import DeeplinkSDK

DeeplinkSDK.configure(apiKey: "your-api-key", domain: "dl.yourapp.com")
```

### Deferred Deep Linking

Call once on first launch (after onboarding) to retrieve the deep link that brought the user to install:

```swift
DeeplinkSDK.getInitData { data in
    guard let data = data else { return }
    // data.destinationUrl — fallback URL
    // data.iosUrl         — iOS-specific deep link URL
    // data.metadata       — [String: String] custom key-value pairs
    // data.creativeName   — creative name (if set on the link)
    // data.creativeId     — creative ID (if set on the link)
    navigateTo(data.iosUrl ?? data.destinationUrl)
}

// Force re-fetch (e.g. for testing)
DeeplinkSDK.getInitData(force: true) { data in ... }

// Reset fetched flag
DeeplinkSDK.resetInitState()
```

### Universal Links (iOS 14+)

In `SceneDelegate.swift`:

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = userActivity.webpageURL else { return }
    DeeplinkSDK.handleIncomingURL(url) { link in
        guard let link = link else { return }
        // link.pathComponents — URL path segments
        // link.params         — query parameters [String: String]
    }
}
```

Enable Universal Links in your `.entitlements` and use the AASA URL from the admin Settings page.

### SKAdNetwork (iOS 14+)

Add the Deeplink AI postback URL to your `Info.plist`:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://your-api.example.com/skan/postback</string>
```

### Event Tracking

```swift
DeeplinkSDK.track("purchase", properties: [
    "amount": 49.99,
    "currency": "USD"
])

DeeplinkSDK.track("signup")
```

---

## Android SDK

### Requirements
- Android API 21+
- Kotlin 1.8+

### Installation

Add the module to your `settings.gradle`:

```groovy
include ':deeplinkSDK'
project(':deeplinkSDK').projectDir = file('../sdk/android/deeplinkSDK')
```

Add dependency in your app's `build.gradle`:

```groovy
dependencies {
    implementation project(':deeplinkSDK')
}
```

### Setup

In your `Application` class:

```kotlin
import com.deeplink.sdk.DeeplinkSDK

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DeeplinkSDK.configure(this, apiKey = "your-api-key", domain = "dl.yourapp.com")
    }
}
```

### Deferred Deep Linking

Call once after onboarding on first launch:

```kotlin
DeeplinkSDK.getInitData { data ->
    data ?: return@getInitData
    // data.destinationUrl — fallback URL
    // data.androidUrl     — Android-specific deep link URL
    // data.metadata       — Map<String, String> custom key-value pairs
    // data.creativeName   — creative name (if set on the link)
    // data.creativeId     — creative ID (if set on the link)
    openDeepLink(data.androidUrl ?: data.destinationUrl)
}

// Force re-fetch (e.g. for testing)
DeeplinkSDK.getInitData(force = true) { data -> ... }

// Reset fetched flag
DeeplinkSDK.resetInitState()
```

### Android App Links

In your `AndroidManifest.xml`:

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

Handle the incoming intent in your Activity:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    DeeplinkSDK.handleIntent(intent) { link ->
        link ?: return@handleIntent
        // link.pathSegments — URL path segments
        // link.params       — query parameters Map<String, String>
    }
}
```

Use the assetlinks URL from the admin Settings page to verify your domain.

### Event Tracking

```kotlin
DeeplinkSDK.track("purchase", mapOf(
    "amount" to 49.99,
    "currency" to "USD"
))

DeeplinkSDK.track("signup")
```

---

## How It Works

1. **Link click** — User taps a deep link; the backend records a fingerprint (IP + user-agent hash)
2. **App install** — User installs the app from the App Store / Play Store
3. **SDK init** — On first launch, the SDK calls `POST /sdk/init` with device fingerprint
4. **Match** — Backend matches fingerprint to the original click and returns the link data
5. **Route** — App navigates to the correct screen with the link's metadata

---

## Backend Integration

The SDKs communicate with the [Deeplink AI Backend](https://github.com/parth0072/deeplink_BE).

| SDK call | Backend endpoint | Description |
|----------|-----------------|-------------|
| `configure()` | — | Stores config locally |
| `getInitData()` | `POST /sdk/init` | Deferred deep link fingerprint match |
| `handleIncomingURL()` / `handleIntent()` | — | Parses URL/intent locally |
| `track()` | `POST /api/events` | Custom event tracking |
