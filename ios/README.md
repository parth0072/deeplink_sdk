# Deeplink iOS SDK

Swift Package for deferred deep linking, universal links, and mobile attribution — self-hosted, no third-party dependencies.

## Requirements

- iOS 14+
- Xcode 15+
- Swift 5.9+

## Installation

### Swift Package Manager (Xcode)

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repo URL: `https://github.com/parth0072/deeplink-ios-sdk`
3. Select **Up to Next Major** version
4. Add `DeeplinkSDK` to your app target

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/parth0072/deeplink-ios-sdk", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["DeeplinkSDK"])
]
```

## Quick Start

### 1. Configure

```swift
// AppDelegate.swift
import DeeplinkSDK

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Deeplink.setDebug(true)  // Remove in production
    Deeplink.configure(apiKey: "your-api-key", domain: "dl.yourapp.com")
    return true
}
```

**Alternative — Info.plist auto-configuration:**

Add these keys to your `Info.plist`:
```xml
<key>DeeplinkAPIKey</key><string>your-api-key</string>
<key>DeeplinkDomain</key><string>dl.yourapp.com</string>
```
Then call `Deeplink.configureFromInfoPlist()` instead.

### 2. Handle Universal Links

```swift
// SceneDelegate.swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard let url = userActivity.webpageURL else { return }
    Deeplink.handleIncomingURL(url) { link in
        guard let link else { return }
        // link.pathComponents, link.params, link.url
        navigateTo(link)
    }
}
```

### 3. Deferred Deep Link (First Launch)

```swift
// Called once on first launch — routes user to the content they clicked before installing
Deeplink.getInitData { data in
    guard let data else { return }
    print("Routed from campaign:", data.utmCampaign ?? "organic")
    navigateTo(data.iosUrl ?? data.destinationUrl)
}
```

### 4. First Install Callback

```swift
// Fires ONLY on true first install — even if there is no deep link to route
Deeplink.onFirstLaunch { data in
    Analytics.track("install", properties: [
        "source": data?.utmSource ?? "organic",
        "campaign": data?.utmCampaign ?? ""
    ])
    if let url = data?.iosUrl { navigateTo(url) }
}
```

### 5. Clipboard Attribution (opt-in)

Enables 100% deterministic matching when the user taps a link in Safari → App Store.
The redirect page writes a click ID to the clipboard; the SDK reads it on first launch.

```swift
// Call before getInitData / onFirstLaunch
Deeplink.checkPasteboardOnInstall()
Deeplink.getInitData { data in ... }
```

> **Note:** Reading the clipboard shows the iOS 16+ "App pasted from..." system toast.
> Only enable if you are comfortable showing that notification to users.

### 6. Create Links

```swift
Deeplink.createLink(
    destination: "https://yourapp.com/product/123",
    params: ["product_id": "123", "promo": "launch10"],
    utmSource: "instagram",
    utmCampaign: "launch"
) { result, error in
    guard let result else { return }
    share(result.url)  // e.g. "https://dl.yourapp.com/abc123"
}
```

### 7. Event Tracking

```swift
Deeplink.track("purchase", properties: ["amount": 49.99, "currency": "USD"])
Deeplink.track("signup")
```

## How Attribution Works

| Scenario | Method | Accuracy |
|---|---|---|
| Same WiFi, same network | IP + device model + screen | ~90 pts |
| Different network (4G → WiFi) | Model + screen + OS + IDFV | ~55–70 pts |
| Reinstall (same device) | Keychain device_id + IDFV | ~95+ pts (deterministic) |
| Clipboard opt-in | Pasteboard click ID | 100% deterministic |
| Enterprise WiFi (100 devices) | Model + screen + OS uniqueness | ~85% |

**No permissions required.** IDFV and Keychain IDs are Apple-approved for first-party attribution.
**No hidden WKWebView / canvas fingerprinting** — removed to comply with App Store guidelines and iOS 17+ restrictions.

## Universal Links Setup

1. Add your domain to **Signing & Capabilities → Associated Domains**: `applinks:dl.yourapp.com`
2. Your backend automatically serves `/.well-known/apple-app-site-association`

## Debug Mode

```swift
Deeplink.setDebug(true)  // Call before configure()
```

Logs are written via `os.log` (visible in Console.app with subsystem `com.deeplink.sdk`)
and printed to Xcode's debug output.

## License

MIT — see [LICENSE](LICENSE)
