# QuickMed route-time and notification update

## What changed

- Google Routes requests now include `X-Android-Package` and `X-Android-Cert`.
  These headers are required when the Routes API key is restricted to an
  Android application.
- The map screen now requests and displays Google travel estimates for driving,
  boda/two-wheeler, public transit, walking and cycling when Google supports the
  mode for the selected route.
- The Google encoded route polyline is drawn on the map.
- A visible error card is shown when Routes API configuration fails instead of
  silently falling back to unrelated estimates.
- The home-page settings icon was replaced by a notification bell. Tapping it
  opens the reminder/notification history screen.
- Medication notification bodies use the same Google Routes service, so the
  scheduled alert contains the destination and all available transport times.

## Google Cloud requirements

Enable **Routes API** for the key in `AndroidManifest.xml`. If the key uses an
Android application restriction, register:

- Package name: `com.example.quickmed`
- The SHA-1 certificate for the build being installed (debug and release
  certificates are different).

The app sends both values to Google automatically in the required request
headers.
