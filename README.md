# Deeplink AI — SDKs

Multi-platform SDKs for the Deeplink AI platform. Handles deferred deep linking, click attribution, link creation, and custom event tracking.

| SDK | Language | Use case |
|-----|----------|----------|
| [iOS](#ios-sdk) | Swift | Native iOS apps |
| [Android](#android-sdk) | Kotlin | Native Android apps |
| [Flutter](#flutter-sdk) | Dart | Cross-platform Flutter apps |
| [Node.js](#nodejs-sdk) | TypeScript | Server-side link creation + analytics |
| [Web](#web-sdk) | TypeScript / JS | Browser fingerprinting + web tracking |

---

## Repository Structure

```
├── ios/                          # iOS SDK (Swift, XCFramework)
├── android/                      # Android SDK (Kotlin Library)
├── flutter/                      # Flutter SDK (Dart, pure HTTP)
├── nodejs/                       # Node.js SDK (TypeScript)
├── web/                          # Web SDK (TypeScript, CDN + ESM)
└── samples/
    └── ios-sample/               # iOS sample app (SwiftUI)
```

---

## iOS SDK

### Requirements
- iOS 14+
- Swift 5.7+
- Xcode 14+

### Installation

#### Swift Package Manager (recommended)

The iOS SDK ships as a pre-built **XCFramework binary** — no compilation required on the consumer side.

**In Xcode:** File → Add Package Dependencies, enter the repository URL, or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/parth0072/deeplink_sdk.git", from: "1.0.0")
]
```

The `Package.swift` uses a `.binaryTarget` pointing to the included `DeeplinkSDK.xcframework`, so Xcode links the pre-built binary directly.

#### Hosted SPM (GitHub Release)

For CI/CD or to pin to a specific release, upload `DeeplinkSDK.xcframework.zip` to a GitHub Release and use:

```swift
.binaryTarget(
    name: "DeeplinkSDK",
    url: "https://github.com/parth0072/deeplink_sdk/releases/download/vX.Y.Z/DeeplinkSDK.xcframework.zip",
    checksum: "<value from DeeplinkSDK.xcframework.zip.sha256>"
)
```

#### Rebuilding the XCFramework

If you need to rebuild from source (e.g. after modifying the SDK):

```bash
cd sdk/ios
bash scripts/build-xcframework.sh
```

This produces a fresh `DeeplinkSDK.xcframework` with device (arm64) and simulator (arm64 + x86_64) slices.

---

### Setup

```swift
// AppDelegate.swift or @main App struct
import DeeplinkSDK

Deeplink.configure(apiKey: "your-api-key", domain: "dl.yourapp.com")
```

> **Note:** The module is `DeeplinkSDK` (import as usual), but the main class is `Deeplink` to avoid a Swift module/class name collision.

### Deferred Deep Linking

Call once on first launch (after onboarding) to retrieve the deep link that brought the user to install:

```swift
Deeplink.getInitData { data in
    guard let data = data else { return }
    // data.destinationUrl — fallback URL
    // data.iosUrl         — iOS-specific deep link URL
    // data.metadata       — [String: String] custom key-value pairs
    // data.creativeName   — creative name (if set on the link)
    // data.creativeId     — creative ID (if set on the link)
    navigateTo(data.iosUrl ?? data.destinationUrl)
}

// Force re-fetch (e.g. for testing)
Deeplink.getInitData(force: true) { data in ... }

// Reset fetched flag
Deeplink.resetInitState()
```

### Universal Links (iOS 14+)

In `SceneDelegate.swift`:

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = userActivity.webpageURL else { return }
    Deeplink.handleIncomingURL(url) { link in
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

### Create Links from the SDK

```swift
Deeplink.createLink(
    destination: "https://yourapp.com/product/123",
    params: ["product_id": "123", "promo": "launch10"],
    utmCampaign: "launch"
) { result, error in
    guard let result = result else { return }
    share(result.url)  // e.g. "https://dl.yourapp.com/abc123"
}
```

### Event Tracking

```swift
Deeplink.track("purchase", properties: [
    "amount": 49.99,
    "currency": "USD"
])

Deeplink.track("signup")
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
| `createLink()` | `POST /sdk/link` | Create a short deep link from the app |
| `track()` | `POST /api/events` | Custom event tracking |

---

## Flutter SDK

### Requirements
- Flutter 3.10+
- Dart 3.0+

### Installation

```yaml
dependencies:
  deeplink_sdk:
    git:
      url: https://github.com/parth0072/deeplink_sdk.git
      path: flutter
```

### Setup

```dart
// main.dart
import 'package:deeplink_sdk/deeplink_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Deeplink.configure(
    apiKey: 'your-api-key',
    domain: 'https://dl.yourapp.com',
  );
  runApp(const MyApp());
}
```

### Deferred Deep Linking

```dart
final data = await Deeplink.getInitData();
if (data != null) {
  final productId = data.metadata['product_id'];
  // Navigate to the correct screen
}
```

### Create a Link

```dart
final link = await Deeplink.createLink(
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl: 'myapp://product/123',
  androidUrl: 'myapp://product/123',
  params: {'product_id': '123'},
  utmCampaign: 'share',
);
Share.share(link!.url);
```

### Event Tracking

```dart
await Deeplink.track('purchase', {'amount': 49.99, 'currency': 'USD'});
await Deeplink.track('signup');
```

---

## Node.js SDK

### Requirements
- Node.js 18+ (uses built-in `fetch`)

### Installation

```bash
npm install @deeplink/node
```

### Usage

```ts
import { DeeplinkClient } from '@deeplink/node';

const client = new DeeplinkClient({
  apiKey: 'your-app-api-key',
  baseUrl: 'https://dl.yourapp.com',
});

// Create a link
const link = await client.createLink({
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl: 'myapp://product/123',
  androidUrl: 'myapp://product/123',
  params: { product_id: '123' },
  utmSource: 'email',
  utmCampaign: 'spring-launch',
});
console.log(link.url); // https://dl.yourapp.com/abc123

// Track a server-side event
await client.track('purchase', { amount: 49.99, currency: 'USD' });

// Get analytics
const stats = await client.getAnalytics('link-id', { from: '2024-01-01', to: '2024-01-31' });
```

---

## Web SDK

### Via CDN

```html
<script src="https://unpkg.com/@deeplink/web/dist/deeplink.min.js"></script>
<script>
  Deeplink.configure({ apiKey: 'your-key', domain: 'https://dl.yourapp.com' });
  Deeplink.track('page_view', { page: location.pathname });
</script>
```

### Via npm

```bash
npm install @deeplink/web
```

```ts
import Deeplink from '@deeplink/web';

Deeplink.configure({ apiKey: 'your-key', domain: 'https://dl.yourapp.com' });

// Deferred deep link (personalise landing page based on what link brought the visitor)
const data = await Deeplink.getInitData();
if (data?.metadata?.promo) showPromo(data.metadata.promo);

// Create a share link from the browser
const link = await Deeplink.createLink({
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl: 'myapp://product/123',
  params: { product_id: '123' },
});
navigator.clipboard.writeText(link.url);

// Track events
await Deeplink.track('cta_click', { button: 'download' });
```

The Web SDK also auto-captures UTM parameters from the URL on `configure()` and stores them in `sessionStorage` for attribution.

