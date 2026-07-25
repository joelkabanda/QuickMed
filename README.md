# QuickMed

QuickMed is a mobile healthcare application designed to support patients beyond hospital visits by improving medication adherence and making it easier to access prescribed medicine.

# Project Abstract

Despite advancements in healthcare systems, patients in Uganda continue to face challenges beyond hospital appointments, particularly in medication adherence and timely access to prescribed drugs. Many patients forget to take medication at the correct time or fail to follow prescribed schedules, which can negatively affect treatment outcomes. Additionally, after receiving prescriptions, patients often struggle to locate pharmacies with available medication and determine the most efficient way to access them. This results in delays, missed doses, and reduced effectiveness of treatment. Existing hospital systems primarily focus on appointment scheduling and do not adequately address post-consultation challenges such as medication management and accessibility.

The proposed system is an enhanced mobile healthcare application that focuses on improving patient outcomes beyond hospital visits. The application provides intelligent medication reminders to ensure patients adhere to prescribed dosage schedules. In addition, it integrates location-based services to identify nearby pharmacies where prescribed medication is available. The system further recommends the fastest route and most efficient means of transport based on the patient’s current location, helping reduce delays in accessing medication.

By combining medication adherence support with real-time navigation and accessibility features, the system bridges the gap between prescription and treatment completion. This approach reduces missed doses, improves recovery outcomes, and enhances patient convenience. Unlike traditional hospital management systems, which primarily focus on appointment scheduling, QuickMed extends healthcare support to the post-consultation phase, making it a more comprehensive and patient-centered innovation.

## Key Features

- Medication reminders and scheduling support
- Pharmacy discovery near the user’s location
- Route and transport recommendations to pharmacies
- User-friendly mobile interface for patients
- Scalable architecture for future healthcare integrations

## Technology Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Google Maps / location services

## Project Structure

The project is organized into modular components to support scalability and maintainability:

```text
lib/
├── main.dart
├── app.dart
├── constants/
│   ├── app_colors.dart
│   ├── app_strings.dart
│   └── app_constants.dart
├── routes/
│   └── app_routes.dart
├── models/  # shared across 2+ features
├── services/  # shared across 2+ features (e.g. api_client.dart)
├── widgets/  # shared/reusable UI components
├── utils/
└── features/
    ├── authentication/
    │   ├── screens/
    │   ├── widgets/
    │   ├── models/
    │   └── services/
    ├── dashboard/
    │   ├── screens/
    │   ├── widgets/
    │   ├── models/
    │   └── services/
    ├── medications/
    │   ├── screens/
    │   ├── widgets/
    │   ├── models/
    │   └── services/
    ├── reminders/
    │   ├── screens/
    │   ├── widgets/
    │   ├── models/
    │   └── services/
    ├── pharmacies/
    │   ├── screens/
    │   ├── widgets/
    │   ├── models/
    │   └── services/
    ├── maps/
    │   ├── screens/
    │   ├── widgets/
    │   ├── models/
    │   └── services/
    ├── profile/
    │   ├── screens/
    │   ├── widgets/
    │   ├── models/
    │   └── services/
    └── settings/
        ├── screens/
        ├── widgets/
        ├── models/
        └── services/
```

This structure separates user-facing screens, business logic, and shared application components, making future expansion easier.

## Getting Started

1. Install Flutter and Dart on your machine.
2. Clone the project repository.
3. Run the following commands:

```bash
flutter pub get
flutter run
```

## Notes

Firebase setup is planned for future implementation, and the app structure is being developed to support that integration smoothly.

## Medication and location-aware reminders

QuickMed schedules one local notification **30 minutes before every selected medication time**. When a pharmacy/destination address is saved, the app reads the user's current location while scheduling and requests Google Maps Routes estimates for driving, boda/two-wheeler, transit, walking, and bicycling. Available travel modes are included in the notification.

### Google Maps setup

1. In Google Cloud Console, enable **Routes API** for your project.
2. Create a replacement API key and restrict it to the Routes API and your Android/iOS applications.
3. Do not commit the key. Run or build with:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_KEY
flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_KEY
```

The key supplied in chat was intentionally not written into the source tree. Rotate it because it has been exposed.

### Runtime behavior

Travel estimates are captured from the user's current position when the medication is saved/rescheduled. Mobile operating systems do not allow an ordinary pre-composed local notification to make a live network request at display time. For continuously refreshed ETAs at the exact notification moment, use a backend push-notification workflow or a platform-specific background task, subject to Android/iOS background-execution limits.
