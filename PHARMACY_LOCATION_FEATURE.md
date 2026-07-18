# QuickMed Pharmacy Location Feature

## Overview
This document describes the new pharmacy location saving and real-time arrival time estimation feature added to QuickMed.

## Features Implemented

### 1. **Location Service** (`lib/services/location_service.dart`)
A comprehensive service for handling location operations:
- Real-time GPS location tracking
- Permission management (Android, iOS, Windows)
- Distance calculation between two coordinates
- Estimated time to arrival (ETA) calculation
- Address geocoding (coordinates to address and vice versa)

**Key Methods:**
- `getCurrentLocation()` - Gets user's current location with permission handling
- `calculateDistance()` - Haversine formula-based distance calculation
- `calculateEstimatedTimeMinutes()` - ETA based on 40 km/h average speed
- `calculateDistanceAndTime()` - Combined distance + time calculation
- `getAddressFromCoordinates()` - Reverse geocoding
- `getCoordinatesFromAddress()` - Forward geocoding

### 2. **Updated User Profile Model** (`lib/models/user_profile_model.dart`)
Added `SavedPharmacyLocation` class and integrated it into `UserProfile`:
- Stores pharmacy ID, name, coordinates, address, and save timestamp
- Serializable to/from Firestore with `toMap()` and `fromMap()`
- Part of user profile for persistence

### 3. **Pharmacy Stat Card Widget** (`lib/features/dashboard/widgets/pharmacy_stat_card.dart`)
A reusable UI component that:
- Displays nearby pharmacy or saved pharmacy location
- Shows real-time distance and estimated arrival time
- Provides "Save Location" button to store pharmacy coordinates
- Displays saved status with check icon
- Allows removing saved locations with confirmation
- Auto-refreshes arrival time every time widget updates

**Props:**
- `pharmacy` - Pharmacy data to display
- `savedLocation` - Currently saved pharmacy location (if any)
- `onSaveLocation` - Callback when location is saved/removed
- `onTap` - Callback when card is tapped

### 4. **Location Permission Dialog** (`lib/features/dashboard/widgets/location_permission_dialog.dart`)
A user-friendly dialog to request location permissions:
- Clear explanation of why location is needed
- "Enable Location" and "Not Now" options
- Handles "Permission Denied Forever" case
- Opens app settings for manual permission grant

### 5. **Splash Screen Update** (`lib/features/authentication/screens/splash_screen.dart`)
Modified to check and request location permissions on app launch:
- After user authentication
- Shows LocationPermissionDialog if permissions not granted
- Non-blocking (allows app to continue even if permission denied)
- Handles edge cases (permission already granted, services disabled, etc.)

## Platform-Specific Setup Required

### Android (`android/app/build.gradle` & `android/app/src/main/AndroidManifest.xml`)
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (`ios/Runner/Info.plist`)
Add to `Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby pharmacies and calculate travel time.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to show nearby pharmacies and calculate travel time.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to show nearby pharmacies and calculate travel time.</string>
```

### Windows (Already supported by geolocator)
No additional setup needed beyond the pubspec.yaml dependencies.

## Usage Example

### Save a Pharmacy Location
```dart
void _handleSavePharmacyLocation(SavedPharmacyLocation location) {
  setState(() {
    _savedPharmacyLocation = location;
  });
  // TODO: Save to Firebase
  // FirebaseFirestore.instance
  //     .collection('users')
  //     .doc(userId)
  //     .update({'savedPharmacyLocation': location.toMap()});
}
```

### Use the Pharmacy Card
```dart
PharmacyStatCard(
  pharmacy: pharmacyData,
  savedLocation: _savedPharmacyLocation,
  onSaveLocation: _handleSavePharmacyLocation,
  onTap: () => navigateToPharmacyMap(),
)
```

### Get Current Location and Calculate ETA
```dart
try {
  final position = await LocationService.getCurrentLocation();
  final result = LocationService.calculateDistanceAndTime(
    position.latitude,
    position.longitude,
    pharmacy.latitude,
    pharmacy.longitude,
  );
  
  print('Distance: ${result['distanceKm']} km');
  print('ETA: ${result['timeText']}');
} catch (e) {
  print('Error: $e');
}
```

## Dependencies Added
- **geolocator** (^10.0.0) - Location tracking and services
- **permission_handler** (^12.0.3) - Permission management
- **geocoding** (^2.1.0) - Address geocoding/reverse geocoding

## Firebase Integration (TODO)
The following needs to be implemented:
1. Update `DatabaseService` to persist `SavedPharmacyLocation` to Firestore
2. Load saved location on dashboard initialization
3. Sync location changes with Firestore real-time updates

Example structure:
```dart
// Save to Firestore
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({
  'savedPharmacyLocation': savedLocation.toMap(),
});

// Load from Firestore
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
    
final savedLocation = SavedPharmacyLocation.fromMap(
  doc['savedPharmacyLocation']
);
```

## Data Flow
1. User opens app → Splash screen checks location permission
2. If not granted → LocationPermissionDialog is shown
3. User saves a pharmacy → PharmacyStatCard.onSaveLocation callback
4. Location is saved to user profile (needs Firestore integration)
5. Card automatically calculates ETA using real-time location
6. Distance/time updates when card rebuilds or user taps refresh

## Future Enhancements
- Real-time location streaming for continuous ETA updates
- Multiple saved pharmacy locations (favorites)
- Pharmacy opening hours display
- Navigation integration (Google Maps/Apple Maps)
- Location sharing for emergency contacts
- Offline location caching
- Background location tracking for medication pickups

## Troubleshooting

### Location shows "--"
- User hasn't granted location permission
- Location services disabled on device
- Geolocator can't access GPS signal (try moving outdoors)

### "Unable to calculate distance"
- User denied location permission
- Location services not enabled
- No internet connection (for geocoding)

### Permissions not requested
- Check platform-specific manifest/plist files
- Ensure permission_handler is properly installed
- Rebuild app after manifest changes
