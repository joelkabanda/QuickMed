# QuickMed build and UI fix

## Build correction
- Added the missing `flutter_local_notifications` import to `dashboard_screen.dart`.
- This resolves the unknown `FlutterLocalNotificationsPlugin` and `AndroidFlutterLocalNotificationsPlugin` errors.

## Authentication UI
- Redesigned login and registration pages using the QuickMed blue palette.
- Added responsive centered cards, improved spacing, validation, password visibility controls and loading states.
- Added a reusable branded authentication header.

## Branding
- Added a modern blue capsule QuickMed logo.
- Updated the Android launcher icons and web favicon.
- Registered the logo asset in `pubspec.yaml`.

## Run after extracting
```bash
flutter clean
flutter pub get
flutter run
```
