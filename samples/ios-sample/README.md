# iOS Sample App — Deeplink SDK Integration

A minimal SwiftUI app demonstrating every feature of the Deeplink iOS SDK.

## What It Tests

| Feature | Where |
|---------|-------|
| `Deeplink.configure()` | `SampleApp.swift` → `init()` |
| `Deeplink.getInitData()` | `SampleApp.swift` init + ContentView button |
| `Deeplink.handleIncomingURL()` | `SampleApp.swift` `.onOpenURL` |
| `Deeplink.createLink()` | ContentView "Create Deep Link" button |
| `Deeplink.track()` | ContentView event tracking buttons |

## Setup

### 1. Open in Xcode

```bash
open samples/ios-sample/SampleApp.xcodeproj
```

Xcode will automatically resolve the local `DeeplinkSDK` package from `../../ios/`.

### 2. Set your API key and domain

Edit `SampleApp/SampleApp.swift`:

```swift
Deeplink.configure(
    apiKey: "YOUR_API_KEY",   // from admin Settings → Apps
    domain: "dl.yourapp.com"  // your backend domain
)
```

### 3. Run on Simulator or Device

Select any iPhone simulator and press **Run** (⌘R).

> The backend must be running and reachable from the device/simulator.
> For local testing, use ngrok (`scripts/dev-remote.sh` in the backend repo).

## SDK Package Dependency

The project references the SDK via a **local SPM path** (`../../ios`), which resolves to the pre-built `DeeplinkSDK.xcframework` via the `Package.swift` binary target.

No manual framework linking required — Xcode handles it automatically.

## Testing Each Feature

### Deferred Deep Link

1. Tap **Get Init Data (force)** — calls `POST /sdk/init` with device fingerprint
2. If a click fingerprint matches, you'll see link data in the log
3. Tap **Reset Init State** to allow re-fetching on the next call

### Create Link

1. Tap **Create Deep Link** — creates a short link via `POST /sdk/link`
2. The generated URL appears below the button with a copy button
3. Open that URL on the device to test the full deeplink → install → match flow

### Event Tracking

Tap any tracking button — events are sent to `POST /api/events` and appear in the admin Funnels / Events pages.

### Universal Links

With Universal Links configured in the backend:

1. Open the short link URL in Safari on the device
2. The app should open and the log should show the incoming URL's path and params
