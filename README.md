# Deeplink AI — SDKs

Multi-platform SDKs for the [Deeplink AI](https://github.com/parth0072/deeplink_BE) platform — deferred deep linking, click attribution, link creation, and custom event tracking across every major platform.

---

## Platforms

| Platform | Language | Folder | Sample |
|----------|----------|--------|--------|
| [iOS](ios/README.md) | Swift | `ios/` | `samples/ios-sample/` |
| [Android](android/README.md) | Kotlin | `android/` | `samples/android-sample/` |
| [Flutter](flutter/README.md) | Dart | `flutter/` | `samples/flutter-sample/` |
| [Node.js](nodejs/README.md) | TypeScript | `nodejs/` | `samples/nodejs-sample/` |
| [Web](web/README.md) | TypeScript / JS | `web/` | `samples/web-sample/` |

---

## Repository Structure

```
deeplink_sdk/
├── ios/                    # iOS SDK — Swift, XCFramework binary via SPM
│   ├── Package.swift
│   ├── DeeplinkSDK.xcframework/
│   ├── DeeplinkSDK.xcframework.zip
│   ├── DeeplinkSDK.xcframework.zip.sha256
│   ├── Sources/DeeplinkSDK/
│   └── scripts/build-xcframework.sh
│
├── android/                # Android SDK — Kotlin library module
│   └── deeplinkSDK/src/main/kotlin/com/deeplink/sdk/
│
├── flutter/                # Flutter SDK — pure Dart, no platform channels
│   └── lib/
│       ├── deeplink_sdk.dart
│       └── src/
│
├── nodejs/                 # Node.js SDK — TypeScript, zero runtime deps
│   └── src/
│
├── web/                    # Web SDK — TypeScript, CDN + ESM + CJS bundles
│   ├── src/
│   └── dist/               # Built output (deeplink.min.js, esm, cjs)
│
└── samples/
    ├── ios-sample/         # SwiftUI sample app
    ├── android-sample/     # Jetpack Compose sample app
    ├── flutter-sample/     # Flutter sample app
    ├── nodejs-sample/      # Node.js demo script + Express server
    └── web-sample/         # Single-page HTML demo
```

---

## How It Works

```
1. Link click    ─→  User taps a Deeplink URL in browser / email / ad
                     Backend records IP + user-agent fingerprint

2. App install   ─→  User installs from App Store / Play Store

3. SDK init      ─→  On first launch, SDK calls POST /sdk/init
                     with device fingerprint + session ID

4. Match         ─→  Backend finds the original click fingerprint
                     and returns the link's destination + metadata

5. Route         ─→  App navigates to the correct screen,
                     pre-filled with the link's params
```

---

## Quick Start

### iOS
```swift
import DeeplinkSDK

Deeplink.configure(apiKey: "your-api-key", domain: "https://dl.yourapp.com")

Deeplink.getInitData { data in
    guard let data else { return }
    navigateTo(data.iosUrl ?? data.destinationUrl)
}
```
→ [Full iOS docs](ios/README.md) · [Sample app](samples/ios-sample/)

---

### Android
```kotlin
DeeplinkSDK.configure(this, apiKey = "your-api-key", domain = "https://dl.yourapp.com")

DeeplinkSDK.getInitData { data ->
    data?.let { openDeepLink(it.androidUrl ?: it.destinationUrl) }
}
```
→ [Full Android docs](android/README.md) · [Sample app](samples/android-sample/)

---

### Flutter
```dart
await Deeplink.configure(apiKey: 'your-api-key', domain: 'https://dl.yourapp.com');

final data = await Deeplink.getInitData();
if (data != null) navigateTo(data.androidUrl ?? data.destinationUrl);
```
→ [Full Flutter docs](flutter/README.md) · [Sample app](samples/flutter-sample/)

---

### Node.js
```ts
import { DeeplinkClient } from '@deeplink/node';

const client = new DeeplinkClient({ apiKey: 'your-api-key', baseUrl: 'https://dl.yourapp.com' });
const link = await client.createLink({ destinationUrl: 'https://yourapp.com/product/123' });
```
→ [Full Node.js docs](nodejs/README.md) · [Sample](samples/nodejs-sample/)

---

### Web
```html
<script src="https://dl.yourapp.com/web/deeplink.min.js"></script>
<script>
  Deeplink.configure({ apiKey: 'your-key', domain: 'https://dl.yourapp.com' });
  Deeplink.track('page_view', { page: location.pathname });
</script>
```
→ [Full Web docs](web/README.md) · [Sample](samples/web-sample/)

---

## API Reference — All Platforms

| Method | iOS | Android | Flutter | Node.js | Web |
|--------|-----|---------|---------|---------|-----|
| `configure` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `getInitData` | ✅ | ✅ | ✅ | — | ✅ |
| `handleIncomingURL` | ✅ | ✅ | ✅ | — | — |
| `createLink` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `track` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `resetInitState` | ✅ | ✅ | ✅ | — | ✅ |

---

## Backend Endpoints

All SDKs communicate with the [Deeplink AI Backend](https://github.com/parth0072/deeplink_BE).

| Endpoint | Auth | Used by |
|----------|------|---------|
| `POST /sdk/init` | `api_key` in body | iOS, Android, Flutter, Web |
| `POST /sdk/link` | `api_key` in body | All |
| `POST /api/events` | `api_key` in body | All |
| `GET /.well-known/apple-app-site-association` | public | iOS Universal Links |
| `GET /.well-known/assetlinks.json` | public | Android App Links |

---

## Releases

| Version | Date | Notes |
|---------|------|-------|
| [v1.0.0](https://github.com/parth0072/deeplink_sdk/releases/tag/v1.0.0) | 2026-03-09 | Initial release — iOS + Android + Flutter + Node.js + Web SDKs |
