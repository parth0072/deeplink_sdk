# Deeplink Flutter SDK

Flutter SDK for deferred deep linking, link creation, and event tracking.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  deeplink_sdk:
    git:
      url: https://github.com/parth0072/deeplink_sdk.git
      path: flutter
```

## Setup

```dart
// main.dart
import 'package:deeplink_sdk/deeplink_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Deeplink.configure(
    apiKey: 'your-app-api-key',
    domain: 'https://dl.yourapp.com',
  );
  runApp(const MyApp());
}
```

## Deferred Deep Linking

Call once after the user completes onboarding:

```dart
final data = await Deeplink.getInitData();
if (data != null) {
  final productId = data.metadata['product_id'];
  // Navigate to the right screen
}
```

## Handle Incoming Links

```dart
// In your MaterialApp.router or onGenerateRoute:
final link = Deeplink.handleIncomingUri(incomingUri);
if (link != null) {
  final page = link.pathSegments.firstOrNull;
  // Navigate based on page + link.params
}
```

## Create a Link

```dart
final link = await Deeplink.createLink(
  destinationUrl: 'https://yourapp.com/product/123',
  iosUrl: 'myapp://product/123',
  androidUrl: 'myapp://product/123',
  params: {'product_id': '123', 'promo': 'launch10'},
  utmSource: 'share_button',
  utmCampaign: 'launch',
);
if (link != null) {
  Share.share(link.url);
}
```

## Track Events

```dart
await Deeplink.track('purchase', {'amount': 49.99, 'currency': 'USD'});
await Deeplink.track('signup');
await Deeplink.track('button_tapped', {'screen': 'home', 'button': 'cta'});
```

## API

| Method | Description |
|--------|-------------|
| `Deeplink.configure(apiKey:, domain:)` | Initialize SDK (call once in `main()`) |
| `Deeplink.getInitData({force:})` | Fetch deferred deep link on first launch |
| `Deeplink.handleIncomingUri(uri)` | Parse an incoming deep link URI |
| `Deeplink.createLink(destinationUrl:, ...)` | Create a short deep link |
| `Deeplink.track(event, properties)` | Track a custom event |
| `Deeplink.resetInitState()` | Reset init guard (for testing) |

## Android Setup

Add to `AndroidManifest.xml` to receive App Links:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="dl.yourapp.com" />
</intent-filter>
```

## iOS Setup

Add to your `Info.plist` for Universal Links:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:dl.yourapp.com</string>
</array>
```
