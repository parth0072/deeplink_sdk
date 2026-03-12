// WebViewBridge.swift — removed.
// Canvas fingerprinting via hidden WKWebView is unreliable on iOS 17+ (WebKit adds
// canvas noise for privacy) and risks App Store rejection under Apple's device
// fingerprinting guidelines.
//
// Replacement: IDFV (identifierForVendor) — see APIClient.fetchInitData().
// IDFV is Apple's own stable per-vendor device identifier:
//   - No ATT permission required
//   - Stable across app reinstalls (resets only if ALL apps from vendor are removed)
//   - Explicitly allowed by App Store guidelines
//   - +50 pts in scoring → deterministic on second install
