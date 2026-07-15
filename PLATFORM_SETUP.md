# Platform Configuration for QuickMed Pharmacy Location Feature

## Android Setup

### 1. Update `android/app/src/main/AndroidManifest.xml`

Add location permissions inside the `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

Example location in file:
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.quickmed.app">

    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application>
        ...
    </application>
</manifest>
```

### 2. Update `android/app/build.gradle`

Ensure minSdkVersion is at least 18 (required for geolocator):

```gradle
android {
    compileSdk 34

    defaultConfig {
        applicationId "com.quickmed.app"
        minSdkVersion 21  // Ensure this is at least 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
    
    ...
}
```

### 3. Android Permissions Runtime

The app uses `permission_handler` to request permissions at runtime. On Android 6.0+ (API 23+), users will see a permission dialog when:
- The app first needs location
- The user hasn't previously granted the permission

### Important Android Notes:
- Geolocator requires Google Play Services location API
- On some devices, you may need to enable "Location" in system settings
- High accuracy location requires GPS to be enabled
- Device must have Google Play Services installed for background location updates

---

## iOS Setup

### 1. Update `ios/Runner/Info.plist`

Add location permission descriptions inside the main `<dict>` tag:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Add these keys for location permissions -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>We need your location to show nearby pharmacies and calculate travel time to your saved pharmacy.</string>
    
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>We need your location to show nearby pharmacies and calculate travel time to your saved pharmacy.</string>
    
    <key>NSLocationAlwaysUsageDescription</key>
    <string>We need your location to show nearby pharmacies and calculate travel time to your saved pharmacy.</string>

    <!-- Other existing keys... -->
</dict>
</plist>
```

### 2. Update `ios/Podfile`

Ensure you're using a recent version of iOS and CocoaPods:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

### 3. iOS Permissions Runtime

The app uses `permission_handler` to request permissions at runtime. On iOS, users will see a permission dialog with the description from Info.plist when:
- The app first needs location
- The user hasn't previously granted the permission

### Important iOS Notes:
- Requires iOS 11.0 or higher
- Always (background) location requires app to be in background modes
- Users can revoke permissions at any time in Settings > Privacy > Location
- High accuracy may reduce battery life

---

## Windows Setup

Windows location support requires:
- Windows 10 or later
- No additional manifest changes needed

### Platform-specific code already handles Windows:
```dart
// The geolocator package automatically handles Windows platform
```

---

## Testing Location Features

### Quick Test Checklist:

1. **App Launch**
   - ✅ Splash screen shows location permission dialog
   - ✅ User can choose "Enable Location" or "Not Now"
   - ✅ App continues to dashboard regardless of choice

2. **Pharmacy Card Display**
   - ✅ Card shows distance and time (if location enabled)
   - ✅ Card shows "--" for distance/time if location not available
   - ✅ "Save Location" button appears on unsaved card

3. **Save Location**
   - ✅ Click "Save Location" button
   - ✅ Location is calculated and saved to Firebase
   - ✅ Card updates to show "Saved Pharmacy" status
   - ✅ Check mark icon replaces pharmacy icon

4. **Remove Location**
   - ✅ Close icon appears on saved card
   - ✅ Click close icon to remove
   - ✅ Confirmation dialog appears
   - ✅ Location is removed from Firebase
   - ✅ Card returns to "Pharmacy nearby" state

5. **Real-time Updates**
   - ✅ Move device location
   - ✅ Distance and time automatically update
   - ✅ No manual refresh needed

### Simulating Location on Emulator:

**Android Emulator:**
```bash
# In Android Studio, open Extended controls (Ctrl+Shift+A or Cmd+Shift+A)
# Go to Location tab
# Set custom location or play recorded route
```

**iOS Simulator:**
```bash
# In Xcode: Debug menu > Simulate Location > choose a city
# Or use code: CLLocationManager with mock locations
```

---

## Troubleshooting

### Issue: "Unable to calculate distance" error
**Solution:**
- Verify location permission is granted in app settings
- Check if Location Services is enabled on device
- Try moving device to open area for GPS signal
- Restart app and device

### Issue: Permission dialog not showing on first launch
**Solution:**
- Verify manifest/plist files have correct permissions
- Rebuild app: `flutter clean && flutter pub get && flutter run`
- Check that permission_handler package is properly installed

### Issue: Distance shows "--" after saving
**Solution:**
- Location permission may be "While In Use" instead of "Always"
- Try opening the Pharmacy card again
- Check device location services are enabled
- Check internet connection for geocoding

### Issue: Saved location doesn't persist after app restart
**Solution:**
- Verify Firebase Firestore collection/document structure
- Check user is properly authenticated
- Verify user has write permissions in Firestore
- Check Firebase console for any errors

### Issue: High battery drain
**Solution:**
- App only requests location when needed (opening dashboard)
- Avoid testing with location updates every second
- Location requests use `LocationAccuracy.high` with 10-second timeout
- Consider using `LocationAccuracy.medium` for less battery drain

---

## Firebase Firestore Structure

Saved pharmacy locations are stored in user documents:

```json
{
  "users": {
    "user_id_123": {
      "savedPharmacyLocation": {
        "pharmacyId": "pharmacy_1",
        "pharmacyName": "HealthFirst Pharmacy",
        "latitude": -1.2921,
        "longitude": 36.8219,
        "address": "123 Main St, Downtown",
        "savedAt": "2026-07-15T15:20:30Z"
      },
      // ... other user fields
    }
  }
}
```

### Firestore Security Rules

Add this to your Firestore rules to allow users to save pharmacy locations:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

---

## Performance Optimization Tips

1. **Reduce Location Accuracy**
   - Change `LocationAccuracy.high` to `LocationAccuracy.medium` if exact location not needed
   - Reduces battery drain and improves response time

2. **Cache Location Results**
   - Implement local caching with expiration (e.g., 5 minutes)
   - Reduce unnecessary location requests

3. **Batch Firestore Updates**
   - Instead of saving immediately, queue updates
   - Batch save every 30 seconds

4. **Use Streams for Real-time Updates**
   - Replace periodic polling with Firestore streams
   - More efficient for location persistence

---

## API References

- [Geolocator Documentation](https://pub.dev/packages/geolocator)
- [Permission Handler Documentation](https://pub.dev/packages/permission_handler)
- [Geocoding Documentation](https://pub.dev/packages/geocoding)
- [Android Location Permissions](https://developer.android.com/training/location/permissions)
- [iOS Location Permissions](https://developer.apple.com/documentation/corelocation/requesting_authorization_for_location_services)
