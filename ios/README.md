# Deeplink iOS SDK

Native Swift SDK for deferred deep linking, link creation, and event tracking on iOS.

← [Back to main SDK docs](../README.md)

---

## Requirements

| | Minimum |
|-|---------|
| iOS | 14.0+ |
| Swift | 5.7+ |
| Xcode | 14+ |

---

## Installation

### Swift Package Manager (recommended)

The SDK ships as a pre-built **XCFramework binary** — no compilation needed.

**In Xcode:** File → Add Package Dependencies → enter the repo URL:

```
https://github.com/parth0072/deeplink_sdk.git
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/parth0072/deeplink_sdk.git", from: "1.0.0")
]
```

### Hosted SPM (pin to a release)

```swift
.binaryTarget(
    name: "DeeplinkSDK",
    url: "https://github.com/parth0072/deeplink_sdk/releases/download/v1.0.0/DeeplinkSDK.xcframework.zip",
    checksum: "c98e4f13d0433e9b9c46d0e86721e28efb7bb92810ff5789fc57b6c1df6c536f"
)
```

### Rebuilding from source

```bash
cd ios
bash scripts/build-xcframework.sh
```

Produces a fresh `DeeplinkSDK.xcframework` for device (arm64) and simulator (arm64 + x86_64).

---

## Setup

Call `configure` once on app launch — before any other SDK method.

```swift
// AppDelegate.swift or @main App struct
import DeeplinkSDK

Deeplink.configure(apiKey: "your-api-key", domain: "https://dl.yourapp.com")
```

> The module name is `DeeplinkSDK` but the main class is `Deeplink` to avoid a Swift name collision.

---

## Deferred Deep Linking

Fetch the deep link that originally brought the user to install your app. Call once after onboarding completes.

```swift
Deeplink.getInitData { data in
    guard let data = data else { return }
    // data.destinationUrl  — fallback web URL
    // data.iosUrl          — iOS-specific deep link (myapp://...)
    // data.metadata        — [String: String] custom key-value pairs set on the link
    // data.utmCampaign     — UTM campaign
    // data.creativeName    — creative name (if set on the link)
    navigateTo(data.iosUrl ?? data.destinationUrl)
}

// Force re-fetch (e.g. during testing)
Deeplink.getInitData(force: true) { data in ... }

// Reset the one-time guard
Deeplink.resetInitState()
```

---

## Universal Links

Handle links when the app is already installed (foreground / background open).

In `SceneDelegate.swift`:

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = userActivity.webpageURL else { return }
    Deeplink.handleIncomingURL(url) { link in
        guard let link = link else { return }
        // link.pathComponents — ["product", "123"]
        // link.params         — ["ref": "email"]
    }
}
```

**Enable Universal Links:**
1. Add `Associated Domains` entitlement: `applinks:dl.yourapp.com`
2. Host the AASA file — URL is shown in Admin → Settings → iOS

---

## SKAdNetwork

Add the postback URL to `Info.plist` to receive iOS 14+ install attribution:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://your-backend.com/skan/postback</string>
```

View postback data in Admin → SKAdNetwork.

---

## Create Links

Generate short deep links from within the app (e.g. share sheets, referral flows).

```swift
Deeplink.createLink(
    destination: "https://yourapp.com/product/123",
    params: ["product_id": "123", "promo": "launch10"],
    iosUrl: "myapp://product/123",
    androidUrl: "myapp://product/123",
    title: "Check this out",
    utmSource: "share",
    utmCampaign: "referral"
) { result, error in
    guard let result = result else { return }
    // result.url   — "https://dl.yourapp.com/abc123"
    // result.alias — "abc123"
    shareSheet(result.url)
}
```

---

## Event Tracking

Track custom events for funnel and cohort analysis.

```swift
// Basic
Deeplink.track("signup")

// With properties
Deeplink.track("purchase", properties: [
    "amount":   49.99,
    "currency": "USD",
    "item_id":  "sku-123"
])

Deeplink.track("button_tapped", properties: [
    "screen": "home",
    "button": "cta"
])
```

View events in Admin → Funnels and Admin → Cohorts.

---

## Sample App

A full SwiftUI sample app is at [`samples/ios-sample/`](../samples/ios-sample/).

```bash
open samples/ios-sample/SampleApp.xcodeproj
```

Demonstrates: configure, getInitData, handleIncomingURL, createLink, track, resetInitState.
