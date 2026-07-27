# QuickMed location-aware medication reminders

## Updated behaviour

- Medication notifications are scheduled 30 minutes before each selected dose time.
- The notification uses the device location available when reminders are generated.
- The saved destination is used first; a medication-specific pharmacy address is used as fallback.
- Google Maps Routes API estimates are shown as separate notification lines for Driving, Boda, Public transit, Walking and Cycling whenever Google returns that mode.
- Android notifications use expanded big-text formatting.
- The Settings test-notification action and its test scheduling code were removed.
- Legacy test notification IDs are cancelled during notification initialization.

## Google API key

The Android key is read from `android/app/src/main/AndroidManifest.xml` through a small MethodChannel in `MainActivity.kt`. A `--dart-define=GOOGLE_MAPS_API_KEY=...` value still takes priority.

Enable Google Maps **Routes API** in the same Google Cloud project. Restrict the Android key by package name and SHA-1 fingerprint.
