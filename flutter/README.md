# Deeplink Flutter SDK

Cross-platform Flutter SDK for deferred deep linking, link creation, and event tracking. Pure Dart — no platform channels required for core functionality.

← [Back to main SDK docs](../README.md)

---

## Requirements

| | Minimum |
|-|---------|
| Flutter | 3.10+ |
| Dart | 3.0+ |

---

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  deeplink_sdk:
    git:
      url: https://github.com/parth0072/deeplink_sdk.git
      path: flutter
```

Then run:

```bash
flutter pub get
```

---

## Setup

Call `configure` once in `main()` before `runApp`.

```dart
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

---

## Deferred Deep Linking

Fetch the deep link that originally brought the user to install your app. Call once after onboarding completes.

```dart
final data = await Deeplink.getInitData();
if (data != null) {
  // data.destinationUrl  — fallback web URL
  // data.iosUrl          — iOS deep link
  // data.androidUrl      — Android deep link
  // data.metadata        — Map<String, dynamic> custom key-value pairs
  navigateTo(data.androidUrl ?? data.destinationUrl);
}

// Force re-fetch (e.g. during testing)
final data = await Deeplink.getInitData(force: true);

// Reset the one-time guard
await Deeplink.resetInitState();
```

---

## Handle Incoming Links

Parse an incoming URI when the app is opened via a deep link.

```dart
final link = Deeplink.handleIncomingUri(uri);
if (link != null) {
  // link.pathSegments — ['product', '123']
  // link.params       — {'ref': 'email'}
  context.go('/${link.pathSegments.firstOrNull}');
}
```

### Android — `AndroidManifest.xml`

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="dl.yourapp.com" />
</intent-filter>
```

### iOS — `Info.plist`

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:dl.yourapp.com</string>
</array>
```

---

## Create Links

Generate short deep links from within the app.

```dart
final link = await Deeplink.createLink(
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl:         'myapp://product/123',
  androidUrl:     'myapp://product/123',
  params:         {'product_id': '123', 'promo': 'launch10'},
  title:          'Check this out',
  utmSource:      'share',
  utmCampaign:    'referral',
);
if (link != null) Share.share(link.url);
```

---

## Event Tracking

```dart
await Deeplink.track('signup');

await Deeplink.track('purchase', {
  'amount':   49.99,
  'currency': 'USD',
});

await Deeplink.track('button_tapped', {
  'screen': 'home',
  'button': 'cta',
});
```

---

## API Reference

| Method | Returns | Description |
|--------|---------|-------------|
| `Deeplink.configure(apiKey:, domain:)` | `Future<void>` | Initialize SDK |
| `Deeplink.getInitData({force:})` | `Future<DeeplinkData?>` | Deferred deep link on first launch |
| `Deeplink.handleIncomingUri(uri)` | `IncomingLink?` | Parse incoming URI |
| `Deeplink.createLink(destinationUrl:, ...)` | `Future<CreatedLink?>` | Create a short deep link |
| `Deeplink.track(event, properties)` | `Future<void>` | Track a custom event |
| `Deeplink.resetInitState()` | `Future<void>` | Reset init guard |

---

## Sample App

[`samples/flutter-sample/`](../samples/flutter-sample/) — full Flutter sample demonstrating every SDK feature.

```bash
cd samples/flutter-sample && flutter pub get && flutter run
```
