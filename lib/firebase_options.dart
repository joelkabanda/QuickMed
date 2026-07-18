import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart' show TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVGWjJk9oNFreXgUe-OXkqFA9FLvxwQSQ',
    appId: '1:985656001334:web:quickmed',
    messagingSenderId: '985656001334',
    projectId: 'campusbites-af75b',
    authDomain: 'campusbites-af75b.firebaseapp.com',
    storageBucket: 'campusbites-af75b.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdKi8FWdBvNRQ5O5P5Qs-L-L6Qs3wQXXU',
    appId: '1:985656001334:android:quickmedc7f8d5d8c9e0f1a2',
    messagingSenderId: '985656001334',
    projectId: 'campusbites-af75b',
    storageBucket: 'campusbites-af75b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCdKi8FWdBvNRQ5O5P5Qs-L-L6Qs3wQXXU',
    appId: '1:985656001334:ios:quickmedc7f8d5d8c9e0f1a2',
    messagingSenderId: '985656001334',
    projectId: 'campusbites-af75b',
    storageBucket: 'campusbites-af75b.firebasestorage.app',
    iosBundleId: 'com.example.quickmed',
  );
}
