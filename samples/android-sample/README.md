# Android Sample App

Sample Android app (Kotlin + Jetpack Compose) demonstrating all Deeplink SDK features.

## Setup

1. Open the `samples/android-sample/` directory in Android Studio.
2. Let Gradle sync — it will pull in the `:deeplinkSDK` module from `../../android/deeplinkSDK`.
3. Run on an emulator or device (API 21+).

## What's Tested

| Feature | Where |
|---------|-------|
| `DeeplinkSDK.configure()` | `SampleApplication.onCreate()` |
| `DeeplinkSDK.getInitData(force:)` | Button → shows matched data in log |
| `DeeplinkSDK.resetInitState()` | Button |
| `DeeplinkSDK.handleIntent()` | `MainActivity.onCreate()` |
| `DeeplinkSDK.createLink()` | Button → shows URL + copy to clipboard |
| `DeeplinkSDK.track()` | Three event buttons (button_tapped, purchase, signup) |

## Credentials

Edit `SampleApplication.kt` to set your own API key and domain:

```kotlin
DeeplinkSDK.configure(
    context = this,
    apiKey  = "your-api-key",
    domain  = "https://your-backend.com",
)
```

## App Links

To test Android App Links, update the `<data>` tag in `AndroidManifest.xml` with your domain and host the `assetlinks.json` file from Admin → Settings.
