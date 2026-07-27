import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Google Maps Routes API client used by the map screen and medication alerts.
///
/// Android-restricted API keys require the package name and SHA-1 certificate
/// headers. QuickMed reads those values from the running Android application
/// through [MethodChannel], so the same restricted key can safely serve the
/// Routes API without being copied into Dart source.
class GoogleRoutesService {
  GoogleRoutesService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _providedApiKey = apiKey;

  static const _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const _configChannel = MethodChannel('quickmed/config');

  final http.Client _client;
  final String? _providedApiKey;
  String? _resolvedApiKey;
  Map<String, String>? _androidIdentity;

  Future<String> _getApiKey() async {
    if (_resolvedApiKey?.trim().isNotEmpty == true) return _resolvedApiKey!;

    final supplied = _providedApiKey?.trim() ?? '';
    if (supplied.isNotEmpty) return _resolvedApiKey = supplied;

    const environmentKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (environmentKey.trim().isNotEmpty) {
      return _resolvedApiKey = environmentKey.trim();
    }

    try {
      final manifestKey =
          await _configChannel.invokeMethod<String>('getGoogleMapsApiKey');
      if (manifestKey?.trim().isNotEmpty == true) {
        return _resolvedApiKey = manifestKey!.trim();
      }
    } on PlatformException catch (error) {
      debugPrint('Unable to read manifest API key: $error');
    }

    throw StateError(
      'Google Maps API key is missing. Add com.google.android.geo.API_KEY '
      'to AndroidManifest.xml or pass GOOGLE_MAPS_API_KEY with --dart-define.',
    );
  }

  Future<Map<String, String>> _getAndroidIdentity() async {
    if (_androidIdentity != null) return _androidIdentity!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _androidIdentity = const {};
    }
    try {
      final value = await _configChannel
          .invokeMapMethod<String, dynamic>('getAndroidAppIdentity');
      final packageName = value?['packageName']?.toString().trim() ?? '';
      final certificate = value?['sha1Certificate']?.toString().trim() ?? '';
      _androidIdentity = {
        if (packageName.isNotEmpty) 'X-Android-Package': packageName,
        if (certificate.isNotEmpty) 'X-Android-Cert': certificate,
      };
    } on PlatformException catch (error) {
      debugPrint('Unable to read Android application identity: $error');
      _androidIdentity = const {};
    }
    return _androidIdentity!;
  }

  Future<List<TravelEstimate>> getTravelEstimates({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final apiKey = await _getApiKey();
    final identityHeaders = await _getAndroidIdentity();
    final modes = <TravelMode>[
      TravelMode.driving,
      TravelMode.twoWheeler,
      TravelMode.transit,
      TravelMode.walking,
      TravelMode.bicycling,
    ];

    final results = await Future.wait(
      modes.map(
        (mode) async {
          try {
            final modern = await _fetchEstimate(
              apiKey: apiKey,
              identityHeaders: identityHeaders,
              mode: mode,
              originLatitude: originLatitude,
              originLongitude: originLongitude,
              destinationLatitude: destinationLatitude,
              destinationLongitude: destinationLongitude,
            );
            if (modern != null) return modern;
            return _fetchLegacyEstimate(
              apiKey: apiKey,
              identityHeaders: identityHeaders,
              mode: mode,
              originLatitude: originLatitude,
              originLongitude: originLongitude,
              destinationLatitude: destinationLatitude,
              destinationLongitude: destinationLongitude,
            );
          } catch (error) {
            debugPrint('Google route ${mode.label} request failed: $error');
            return null;
          }
        },
      ),
    );

    final available = results.whereType<TravelEstimate>().toList();
    if (available.isNotEmpty) return available;

    // A restricted key or an unavailable transport mode must not leave the
    // user without guidance. Use conservative distance-based estimates as a
    // visible fallback while keeping the Google Maps navigation action.
    debugPrint('Google Routes returned no usable routes; using local fallback estimates.');
    return _buildFallbackEstimates(
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );
  }

  List<TravelEstimate> _buildFallbackEstimates({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) {
    const earthRadiusMeters = 6371000.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(destinationLatitude - originLatitude);
    final dLon = radians(destinationLongitude - originLongitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(originLatitude)) *
            math.cos(radians(destinationLatitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final straightLine = earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final roadDistance = math.max(100.0, straightLine * 1.28);

    TravelEstimate estimate(TravelMode mode, double kmPerHour, {double factor = 1}) {
      final seconds = math.max(60, ((roadDistance / 1000) / kmPerHour * 3600 * factor).round());
      return TravelEstimate(
        mode: mode,
        duration: Duration(seconds: seconds),
        distanceMeters: roadDistance.round(),
        isFallback: true,
      );
    }

    return [
      estimate(TravelMode.driving, 24, factor: 1.15),
      estimate(TravelMode.twoWheeler, 28, factor: 1.05),
      estimate(TravelMode.transit, 18, factor: 1.35),
      estimate(TravelMode.walking, 4.8),
      estimate(TravelMode.bicycling, 14),
    ];
  }

  Future<TravelEstimate?> _fetchEstimate({
    required String apiKey,
    required Map<String, String> identityHeaders,
    required TravelMode mode,
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final body = <String, dynamic>{
      'origin': {
        'location': {
          'latLng': {
            'latitude': originLatitude,
            'longitude': originLongitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destinationLatitude,
            'longitude': destinationLongitude,
          },
        },
      },
      'travelMode': mode.apiValue,
      'computeAlternativeRoutes': false,
      'languageCode': 'en',
      'units': 'METRIC',
    };

    if (mode == TravelMode.driving || mode == TravelMode.twoWheeler) {
      body['routingPreference'] = 'TRAFFIC_AWARE';
    }

    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
            ...identityHeaders,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        'Routes API ${mode.label} failed (${response.statusCode}): ${response.body}',
      );
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = decoded['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final durationSeconds = _parseDurationSeconds(route['duration'] as String?);
    final distanceMeters = (route['distanceMeters'] as num?)?.toInt() ?? 0;
    final polyline = (route['polyline'] as Map<String, dynamic>?)?
        ['encodedPolyline']
        ?.toString();
    if (durationSeconds <= 0) return null;

    return TravelEstimate(
      mode: mode,
      duration: Duration(seconds: durationSeconds),
      distanceMeters: distanceMeters,
      encodedPolyline: polyline,
    );
  }

  Future<TravelEstimate?> _fetchLegacyEstimate({
    required String apiKey,
    required Map<String, String> identityHeaders,
    required TravelMode mode,
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final legacyMode = switch (mode) {
      TravelMode.driving => 'driving',
      TravelMode.twoWheeler => 'driving',
      TravelMode.transit => 'transit',
      TravelMode.walking => 'walking',
      TravelMode.bicycling => 'bicycling',
    };
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '$originLatitude,$originLongitude',
      'destination': '$destinationLatitude,$destinationLongitude',
      'mode': legacyMode,
      'departure_time': 'now',
      'key': apiKey,
    });
    final response = await _client.get(uri, headers: identityHeaders)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['status'] != 'OK') {
      debugPrint('Directions API ${mode.label}: ${decoded['status']} ${decoded['error_message'] ?? ''}');
      return null;
    }
    final routes = decoded['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;
    final leg = legs.first as Map<String, dynamic>;
    final durationNode = (leg['duration_in_traffic'] ?? leg['duration']) as Map<String, dynamic>?;
    final seconds = (durationNode?['value'] as num?)?.toInt() ?? 0;
    final meters = ((leg['distance'] as Map<String, dynamic>?)?['value'] as num?)?.toInt() ?? 0;
    final polyline = (route['overview_polyline'] as Map<String, dynamic>?)?['points']?.toString();
    if (seconds <= 0) return null;
    return TravelEstimate(
      mode: mode,
      duration: Duration(seconds: seconds),
      distanceMeters: meters,
      encodedPolyline: polyline,
    );
  }

  int _parseDurationSeconds(String? value) {
    if (value == null || !value.endsWith('s')) return 0;
    return double.tryParse(value.substring(0, value.length - 1))?.round() ?? 0;
  }
}

enum TravelMode { driving, twoWheeler, transit, walking, bicycling }

extension TravelModeValue on TravelMode {
  String get apiValue {
    switch (this) {
      case TravelMode.driving:
        return 'DRIVE';
      case TravelMode.twoWheeler:
        return 'TWO_WHEELER';
      case TravelMode.transit:
        return 'TRANSIT';
      case TravelMode.walking:
        return 'WALK';
      case TravelMode.bicycling:
        return 'BICYCLE';
    }
  }

  String get label {
    switch (this) {
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.twoWheeler:
        return 'Boda';
      case TravelMode.transit:
        return 'Public transit';
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.bicycling:
        return 'Cycling';
    }
  }
}

class TravelEstimate {
  const TravelEstimate({
    required this.mode,
    required this.duration,
    required this.distanceMeters,
    this.encodedPolyline,
    this.isFallback = false,
  });

  final TravelMode mode;
  final Duration duration;
  final int distanceMeters;
  final String? encodedPolyline;
  final bool isFallback;

  int get minutes => (duration.inSeconds / 60).ceil();

  String get durationText {
    final value = minutes;
    if (value < 60) return '$value min';
    final hours = value ~/ 60;
    final remaining = value % 60;
    return remaining == 0 ? '${hours} hr' : '${hours} hr ${remaining} min';
  }

  String get distanceText {
    if (distanceMeters < 1000) return '$distanceMeters m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get notificationLine => '${mode.label}: $durationText';
}
