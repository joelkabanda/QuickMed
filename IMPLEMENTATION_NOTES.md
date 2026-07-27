# QuickMed reminder update

Implemented:
- Medication notifications scheduled 30 minutes before each selected dose time.
- Saved destination address resolved to coordinates.
- Current device location used as the route origin when reminders are scheduled.
- Google Maps Routes API estimates requested for Drive, Boda/two-wheeler, Transit, Walk, and Bicycle.
- Available mode estimates appended to the notification body.
- API key read securely from `--dart-define=GOOGLE_MAPS_API_KEY=...`.
- Notifications are one-off per generated occurrence, avoiding overlapping daily repeats.

Security:
- The key shared in chat is not included in this codebase. Revoke/rotate it and restrict the replacement key.

Validation note:
- Flutter/Dart SDK was not installed in the execution environment, so automated `flutter analyze` and `flutter test` could not be run here. The code was reviewed and the updated service tests are included.
