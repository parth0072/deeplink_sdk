# Flutter Sample App

Sample Flutter app demonstrating all Deeplink SDK features.

## Setup

```bash
cd samples/flutter-sample
flutter pub get
flutter run
```

## What's Tested

| Feature | UI |
|---------|-----|
| `Deeplink.configure()` | `main()` on startup |
| `Deeplink.getInitData(force:)` | Button → shows matched data in log |
| `Deeplink.resetInitState()` | Button |
| `Deeplink.handleIncomingUri()` | `onGenerateRoute` handler |
| `Deeplink.createLink()` | Button → shows URL + copy to clipboard |
| `Deeplink.track()` | Three event buttons (button_tapped, purchase, signup) |

## Credentials

Edit `lib/main.dart` to set your own API key and domain:

```dart
await Deeplink.configure(
  apiKey: 'your-api-key',
  domain: 'https://your-backend.com',
);
```
