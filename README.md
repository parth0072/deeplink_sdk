# Deeplink AI — Mobile SDKs

Native mobile SDKs for the Deeplink AI platform. Handles deferred deep linking, click attribution, and custom event tracking.

---

## Repository Structure

```
├── ios/                  # iOS SDK (Swift Package)
│   ├── Package.swift
│   └── Sources/
│       └── DeeplinkSDK/
└── android/              # Android SDK (Kotlin Library)
    ├── build.gradle
    └── deeplinkSDK/
        └── src/
```

---

## iOS SDK

### Requirements
- iOS 14+
- Swift 5.7+
- Xcode 14+

### Installation

#### Swift Package Manager

In Xcode: **File → Add Packages** and enter the repository URL, or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/parth0072/deeplink_sdk.git", from: "1.0.0")
]
```

### Setup

```swift
import DeeplinkSDK

@main
struct MyApp: App {
    init() {
        DeeplinkSDK.shared.configure(
            apiKey: "your_api_key",
            baseURL: "https://your-api.example.com"
        )
    }
}
```

### Deferred Deep Linking

Call on app launch to retrieve the deep link data for a user who installed via a link:

```swift
DeeplinkSDK.shared.initialize { result in
    switch result {
    case .success(let data):
        if let alias = data["alias"] as? String {
            // Navigate to the appropriate screen
        }
    case .failure(let error):
        print("No deferred link found: \(error)")
    }
}
```

### Universal Links (iOS 14+)

Add the Deeplink AI postback URL to your `Info.plist`:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://your-api.example.com/skan/postback</string>
```

Enable Universal Links in your entitlements and use the AASA URL from the admin Settings page.

### Event Tracking

```swift
DeeplinkSDK.shared.track(event: "purchase", properties: [
    "amount": 49.99,
    "currency": "USD"
])
```

---

## Android SDK

### Requirements
- Android API 21+
- Kotlin 1.8+

### Installation

Add to your module's `build.gradle`:

```groovy
dependencies {
    implementation project(':deeplinkSDK')
}
```

Or if publishing to Maven:

```groovy
dependencies {
    implementation 'com.deeplink:sdk:1.0.0'
}
```

### Setup

In your `Application` class:

```kotlin
import com.deeplink.sdk.DeeplinkSDK

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DeeplinkSDK.init(
            context = this,
            apiKey = "your_api_key",
            baseUrl = "https://your-api.example.com"
        )
    }
}
```

### Deferred Deep Linking

```kotlin
DeeplinkSDK.getInstance().initialize { result ->
    result.onSuccess { data ->
        val alias = data["alias"] as? String
        // Navigate to the appropriate screen
    }
    result.onFailure { error ->
        Log.d("DeeplinkSDK", "No deferred link: ${error.message}")
    }
}
```

### Android App Links

Add the assetlinks URL from the admin Settings page to verify your domain. In your `AndroidManifest.xml`:

```xml
<activity android:name=".MainActivity">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="your-api.example.com" />
    </intent-filter>
</activity>
```

### Event Tracking

```kotlin
DeeplinkSDK.getInstance().track(
    event = "purchase",
    properties = mapOf("amount" to 49.99, "currency" to "USD")
)
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

| SDK call | Backend endpoint |
|----------|-----------------|
| `initialize()` | `POST /sdk/init` |
| `track(event:)` | `POST /api/events` |
