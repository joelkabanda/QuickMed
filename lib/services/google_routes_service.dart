import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Provides road-following routes for the map and medication travel reminders.
///
/// Google Directions is tried first because it shares the Maps host that is
/// commonly reachable on Android. Google Routes is then used when needed for
/// traffic-aware results. If either web service is unavailable, QuickMed falls
/// back to public road-network routing instead of drawing a straight line.
class GoogleRoutesService {
  GoogleRoutesService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _providedApiKey = apiKey;

  static const _routesEndpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const _configChannel = MethodChannel('quickmed/config');

  final http.Client _client;
  final String? _providedApiKey;
  final List<String> _requestFailures = <String>[];

  String? _resolvedApiKey;
  Map<String, String>? _androidIdentity;

  // A DNS failure should not trigger five identical requests every minute.
  // These short circuit breakers are shared by service instances and reset
  // automatically, so a later refresh can recover when connectivity returns.
  static DateTime? _directionsHostUnavailableUntil;
  static DateTime? _routesHostUnavailableUntil;

  Future<String> _getApiKey() async {
    if (_resolvedApiKey?.trim().isNotEmpty == true) return _resolvedApiKey!;

    final supplied = _providedApiKey?.trim() ?? '';
    if (supplied.isNotEmpty) return _resolvedApiKey = supplied;

    const routesEnvironmentKey =
        String.fromEnvironment('GOOGLE_ROUTES_API_KEY');
    if (routesEnvironmentKey.trim().isNotEmpty) {
      return _resolvedApiKey = routesEnvironmentKey.trim();
    }

    const mapsEnvironmentKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (mapsEnvironmentKey.trim().isNotEmpty) {
      return _resolvedApiKey = mapsEnvironmentKey.trim();
    }

    // A separate Routes key is supported because Google web-service APIs and
    // the Android Maps SDK may use different API restrictions.
    try {
      final routesKey =
          await _configChannel.invokeMethod<String>('getGoogleRoutesApiKey');
      if (routesKey?.trim().isNotEmpty == true) {
        return _resolvedApiKey = routesKey!.trim();
      }
    } on PlatformException catch (error) {
      debugPrint('Unable to read the Routes API key: $error');
    }

    try {
      final manifestKey =
          await _configChannel.invokeMethod<String>('getGoogleMapsApiKey');
      if (manifestKey?.trim().isNotEmpty == true) {
        return _resolvedApiKey = manifestKey!.trim();
      }
    } on PlatformException catch (error) {
      debugPrint('Unable to read the Maps API key: $error');
    }

    throw StateError(
      'Google Maps API key is missing. Add the Android Maps key to '
      'AndroidManifest.xml or pass GOOGLE_MAPS_API_KEY with --dart-define.',
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
      final certificate = value?['sha1Certificate']
              ?.toString()
              .replaceAll(':', '')
              .trim()
              .toUpperCase() ??
          '';
      _androidIdentity = {
        if (packageName.isNotEmpty) 'X-Android-Package': packageName,
        if (certificate.isNotEmpty) 'X-Android-Cert': certificate,
      };
    } catch (error) {
      debugPrint('Unable to read Android application identity: $error');
      _androidIdentity = const {};
    }
    return _androidIdentity!;
  }

  /// Returns the fastest estimate available for every transport mode.
  Future<List<TravelEstimate>> getTravelEstimates({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final plan = await getRoutePlan(
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );
    return plan.estimates;
  }

  /// Returns transport estimates and road-following route polylines.
  Future<RoutePlan> getRoutePlan({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    _requestFailures.clear();

    const modes = <TravelMode>[
      TravelMode.driving,
      TravelMode.twoWheeler,
      TravelMode.transit,
      TravelMode.walking,
      TravelMode.bicycling,
    ];

    var apiKey = '';
    Map<String, String> identityHeaders = const <String, String>{};
    try {
      apiKey = await _getApiKey();
      identityHeaders = await _getAndroidIdentity();
    } catch (error) {
      // A missing or unreadable Google key must not prevent the road-network
      // fallback from drawing a genuine route.
      _recordFailure('Google configuration: $error');
      debugPrint('Google route configuration unavailable: $error');
    }

    final allRoutes = <TravelRoute>[];
    final unresolvedModes = modes.toSet();

    // Try the Directions endpoint first. On some phones routes.googleapis.com
    // is blocked by Private DNS or a network filter even while Google Maps tiles
    // continue to load. maps.googleapis.com usually remains reachable.
    if (apiKey.isNotEmpty && !_hostIsCoolingDown(_directionsHostUnavailableUntil)) {
      for (final mode in modes) {
        try {
          final routes = await _fetchLegacyRoutes(
            apiKey: apiKey,
            identityHeaders: identityHeaders,
            mode: mode,
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
          );
          final usable = routes.where(_hasUsableRoadGeometry).toList();
          allRoutes.addAll(usable);
          if (usable.isNotEmpty) unresolvedModes.remove(mode);
        } catch (error) {
          _recordFailure('Directions ${mode.label}: $error');
          debugPrint('Google Directions ${mode.label} request failed: $error');
          if (_isConnectivityFailure(error)) {
            _directionsHostUnavailableUntil =
                DateTime.now().add(const Duration(minutes: 2));
            break;
          }
        }
      }
    }

    // Use the modern Routes API only for transport modes that Directions did
    // not resolve. A DNS failure opens a two-minute circuit breaker so the app
    // proceeds immediately to the road-network fallback instead of retrying the
    // same unreachable host for every mode.
    if (apiKey.isNotEmpty &&
        unresolvedModes.isNotEmpty &&
        !_hostIsCoolingDown(_routesHostUnavailableUntil)) {
      for (final mode in unresolvedModes.toList()) {
        try {
          final routes = await _fetchModernRoutes(
            apiKey: apiKey,
            identityHeaders: identityHeaders,
            mode: mode,
            originLatitude: originLatitude,
            originLongitude: originLongitude,
            destinationLatitude: destinationLatitude,
            destinationLongitude: destinationLongitude,
          );
          final usable = routes.where(_hasUsableRoadGeometry).toList();
          allRoutes.addAll(usable);
          if (usable.isNotEmpty) unresolvedModes.remove(mode);
        } catch (error) {
          _recordFailure('Routes ${mode.label}: $error');
          debugPrint('Google Routes ${mode.label} request failed: $error');
          if (_isConnectivityFailure(error)) {
            _routesHostUnavailableUntil =
                DateTime.now().add(const Duration(minutes: 2));
            break;
          }
        }
      }
    }

    // Last resort: request actual road geometry from independent OSRM mirrors.
    // Walking and cycling use their own routing profiles whenever available.
    if (unresolvedModes.isNotEmpty) {
      try {
        final fallbackRoutes = await _fetchRoadNetworkFallback(
          modes: unresolvedModes,
          originLatitude: originLatitude,
          originLongitude: originLongitude,
          destinationLatitude: destinationLatitude,
          destinationLongitude: destinationLongitude,
        );
        final usable = fallbackRoutes.where(_hasUsableRoadGeometry).toList();
        allRoutes.addAll(usable);
        unresolvedModes.removeAll(usable.map((route) => route.mode));
      } catch (error) {
        _recordFailure('Road-network fallback: $error');
        debugPrint('Road-network fallback failed: $error');
      }
    }

    if (allRoutes.isEmpty) {
      final detail = _requestFailures.isEmpty
          ? ''
          : ' Technical detail: ${_requestFailures.first}';
      throw StateError(
        'No routing service could be reached. Check mobile data or Wi-Fi, '
        'disable any VPN or Private DNS filter, then tap Retry.$detail',
      );
    }

    final estimates = <TravelEstimate>[];
    for (final mode in modes) {
      final modeRoutes = allRoutes.where((route) => route.mode == mode).toList()
        ..sort((a, b) => a.duration.compareTo(b.duration));
      if (modeRoutes.isEmpty) continue;
      estimates.add(modeRoutes.first.toEstimate());
    }

    return RoutePlan(
      estimates: estimates,
      routes: allRoutes,
      hasLiveTraffic: allRoutes.any((route) => route.isTrafficAware),
      usesFallbackRoutes: allRoutes.any(
        (route) => route.source == RouteDataSource.roadNetworkFallback,
      ),
    );
  }

  bool _hasUsableRoadGeometry(TravelRoute route) {
    return route.distanceMeters > 0 &&
        route.encodedPolyline?.trim().isNotEmpty == true;
  }

  bool _hostIsCoolingDown(DateTime? until) {
    return until != null && DateTime.now().isBefore(until);
  }

  bool _isConnectivityFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('connection refused') ||
        message.contains('network is unreachable') ||
        message.contains('timeoutexception') ||
        message.contains('timed out');
  }

  Future<List<TravelRoute>> _fetchModernRoutes({
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
      'computeAlternativeRoutes': mode == TravelMode.driving,
      'languageCode': 'en',
      'units': 'METRIC',
    };

    if (mode == TravelMode.driving || mode == TravelMode.twoWheeler) {
      body['routingPreference'] = 'TRAFFIC_AWARE';
    }

    final standardHeaders = <String, String>{
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,'
          'routes.polyline.encodedPolyline,routes.routeLabels',
      ...identityHeaders,
    };

    var response = await _client
        .post(
          Uri.parse(_routesEndpoint),
          headers: standardHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    // Some API-key configurations authenticate the key through the standard
    // query parameter rather than X-Goog-Api-Key. Retry only after an auth-like
    // failure so normal requests are not duplicated.
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        identityHeaders.isNotEmpty) {
      final queryKeyUri = Uri.parse(_routesEndpoint).replace(
        queryParameters: <String, String>{'key': apiKey},
      );
      response = await _client
          .post(
            queryKeyUri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Goog-FieldMask':
                  'routes.duration,routes.distanceMeters,'
                  'routes.polyline.encodedPolyline,routes.routeLabels',
              ...identityHeaders,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _googleErrorMessage(response.body);
      _recordFailure(
        'Routes API ${mode.label} (${response.statusCode})${message.isEmpty ? '' : ': $message'}',
      );
      return const [];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = decoded['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return const [];

    final parsed = <TravelRoute>[];
    for (var index = 0; index < routes.length; index++) {
      final route = routes[index] as Map<String, dynamic>;
      final durationSeconds =
          _parseDurationSeconds(route['duration'] as String?);
      final distanceMeters = (route['distanceMeters'] as num?)?.toInt() ?? 0;
      final polyline = (route['polyline'] as Map<String, dynamic>?)?
          ['encodedPolyline']
          ?.toString();
      if (durationSeconds <= 0 ||
          distanceMeters <= 0 ||
          polyline == null ||
          polyline.isEmpty) {
        continue;
      }

      final labels = (route['routeLabels'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const <String>[];
      parsed.add(
        TravelRoute(
          id: '${mode.name}_${index}_${distanceMeters}_$durationSeconds',
          mode: mode,
          duration: Duration(seconds: durationSeconds),
          distanceMeters: distanceMeters,
          encodedPolyline: polyline,
          label: labels.contains('DEFAULT_ROUTE')
              ? 'Recommended route'
              : 'Alternative route ${index + 1}',
          isRecommended: labels.contains('DEFAULT_ROUTE') || index == 0,
          source: RouteDataSource.googleRoutes,
          isTrafficAware:
              mode == TravelMode.driving || mode == TravelMode.twoWheeler,
        ),
      );
    }
    return parsed;
  }

  Future<List<TravelRoute>> _fetchLegacyRoutes({
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

    final query = <String, String>{
      'origin': '$originLatitude,$originLongitude',
      'destination': '$destinationLatitude,$destinationLongitude',
      'mode': legacyMode,
      'alternatives': mode == TravelMode.driving ? 'true' : 'false',
      'key': apiKey,
    };
    if (mode == TravelMode.driving ||
        mode == TravelMode.twoWheeler ||
        mode == TravelMode.transit) {
      query['departure_time'] = 'now';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      query,
    );

    var response = await _client
        .get(uri, headers: identityHeaders)
        .timeout(const Duration(seconds: 12));
    var decoded = _decodeObject(response.body);

    // A server-style Routes key may not use Android application headers.
    // Retry without them only if the first response was denied.
    if (identityHeaders.isNotEmpty &&
        _isDeniedDirectionsResponse(response.statusCode, decoded)) {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
      decoded = _decodeObject(response.body);
    }

    if (response.statusCode != 200) {
      _recordFailure('Directions API ${mode.label} (${response.statusCode})');
      return const [];
    }

    final status = decoded['status']?.toString() ?? '';
    if (status != 'OK') {
      final message = decoded['error_message']?.toString() ?? '';
      _recordFailure(
        'Directions API ${mode.label}: $status${message.isEmpty ? '' : ' - $message'}',
      );
      return const [];
    }

    final routes = decoded['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return const [];

    final parsed = <TravelRoute>[];
    for (var index = 0; index < routes.length; index++) {
      final route = routes[index] as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) continue;
      final leg = legs.first as Map<String, dynamic>;
      final trafficNode = leg['duration_in_traffic'] as Map<String, dynamic>?;
      final durationNode =
          (trafficNode ?? leg['duration']) as Map<String, dynamic>?;
      final seconds = (durationNode?['value'] as num?)?.toInt() ?? 0;
      final meters =
          ((leg['distance'] as Map<String, dynamic>?)?['value'] as num?)
                  ?.toInt() ??
              0;
      final polyline =
          (route['overview_polyline'] as Map<String, dynamic>?)?['points']
              ?.toString();
      if (seconds <= 0 ||
          meters <= 0 ||
          polyline == null ||
          polyline.isEmpty) {
        continue;
      }

      parsed.add(
        TravelRoute(
          id: 'legacy_${mode.name}_${index}_${meters}_$seconds',
          mode: mode,
          duration: Duration(seconds: seconds),
          distanceMeters: meters,
          encodedPolyline: polyline,
          label: index == 0
              ? 'Recommended route'
              : 'Alternative route ${index + 1}',
          isRecommended: index == 0,
          source: RouteDataSource.googleDirections,
          isTrafficAware: trafficNode != null,
        ),
      );
    }
    return parsed;
  }

  /// Last-resort road geometry used when Google web-service routing cannot be
  /// reached. Distances are measured along the returned road/path geometry.
  Future<List<TravelRoute>> _fetchRoadNetworkFallback({
    required Set<TravelMode> modes,
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    if (modes.isEmpty) return const <TravelRoute>[];

    final coordinates =
        '${originLongitude.toStringAsFixed(6)},${originLatitude.toStringAsFixed(6)};'
        '${destinationLongitude.toStringAsFixed(6)},${destinationLatitude.toStringAsFixed(6)}';
    final result = <TravelRoute>[];
    final profileFailures = <String>[];

    Future<void> loadProfile({
      required String profileName,
      required Set<TravelMode> profileModes,
      required List<String> endpoints,
      required bool alternatives,
    }) async {
      if (profileModes.isEmpty) return;
      try {
        final rawRoutes = await _requestOsrmRoutes(
          coordinates: coordinates,
          endpoints: endpoints,
          alternatives: alternatives,
        );
        result.addAll(
          _buildFallbackRoutes(
            rawRoutes: rawRoutes,
            modes: profileModes,
            profileName: profileName,
          ),
        );
      } catch (error) {
        profileFailures.add('$profileName: $error');
      }
    }

    final roadModes = modes
        .where(
          (mode) => mode == TravelMode.driving ||
              mode == TravelMode.twoWheeler ||
              mode == TravelMode.transit,
        )
        .toSet();
    await loadProfile(
      profileName: 'road',
      profileModes: roadModes,
      alternatives: true,
      endpoints: const <String>[
        'https://router.project-osrm.org/route/v1/driving',
        'https://routing.openstreetmap.de/routed-car/route/v1/driving',
      ],
    );

    if (modes.contains(TravelMode.walking)) {
      await loadProfile(
        profileName: 'walking',
        profileModes: const <TravelMode>{TravelMode.walking},
        alternatives: false,
        endpoints: const <String>[
          'https://routing.openstreetmap.de/routed-foot/route/v1/driving',
          // A car-profile road route is preferable to a straight line when the
          // public pedestrian mirror is temporarily unavailable.
          'https://router.project-osrm.org/route/v1/driving',
        ],
      );
    }

    if (modes.contains(TravelMode.bicycling)) {
      await loadProfile(
        profileName: 'cycling',
        profileModes: const <TravelMode>{TravelMode.bicycling},
        alternatives: false,
        endpoints: const <String>[
          'https://routing.openstreetmap.de/routed-bike/route/v1/driving',
          'https://router.project-osrm.org/route/v1/driving',
        ],
      );
    }

    if (result.isEmpty) {
      throw StateError(
        profileFailures.isEmpty
            ? 'no road route was returned'
            : profileFailures.join(' | '),
      );
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _requestOsrmRoutes({
    required String coordinates,
    required List<String> endpoints,
    required bool alternatives,
  }) async {
    Object? lastError;

    for (final endpoint in endpoints) {
      final uri = Uri.parse('$endpoint/$coordinates').replace(
        queryParameters: <String, String>{
          'overview': 'full',
          'geometries': 'polyline',
          'alternatives': alternatives ? 'true' : 'false',
          'steps': 'false',
        },
      );

      try {
        final response = await _client.get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'QuickMed/1.0 (in-app road routing)',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode != 200) {
          lastError = StateError(
            '${uri.host} returned ${response.statusCode}',
          );
          continue;
        }

        final decoded = _decodeObject(response.body);
        if (decoded['code']?.toString().toLowerCase() != 'ok') {
          lastError = StateError(
            decoded['message']?.toString() ?? '${uri.host} found no route',
          );
          continue;
        }

        final rawRoutes = decoded['routes'] as List<dynamic>?;
        if (rawRoutes == null || rawRoutes.isEmpty) {
          lastError = StateError('${uri.host} returned no road route');
          continue;
        }

        return rawRoutes
            .whereType<Map<String, dynamic>>()
            .take(3)
            .toList();
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError(lastError?.toString() ?? 'all route mirrors failed');
  }

  List<TravelRoute> _buildFallbackRoutes({
    required List<Map<String, dynamic>> rawRoutes,
    required Set<TravelMode> modes,
    required String profileName,
  }) {
    final routes = <TravelRoute>[];

    for (var index = 0; index < rawRoutes.length; index++) {
      final raw = rawRoutes[index];
      final distanceMeters = (raw['distance'] as num?)?.round() ?? 0;
      final baseDurationSeconds = (raw['duration'] as num?)?.round() ?? 0;
      final polyline = raw['geometry']?.toString() ?? '';
      if (distanceMeters <= 0 ||
          baseDurationSeconds <= 0 ||
          polyline.isEmpty) {
        continue;
      }

      for (final mode in modes) {
        final seconds = _fallbackDurationSeconds(
          mode: mode,
          distanceMeters: distanceMeters,
          drivingSeconds: baseDurationSeconds,
        );
        routes.add(
          TravelRoute(
            id: 'fallback_${profileName}_${mode.name}_${index}_${distanceMeters}_$seconds',
            mode: mode,
            duration: Duration(seconds: seconds),
            distanceMeters: distanceMeters,
            encodedPolyline: polyline,
            label: index == 0
                ? 'Recommended road route'
                : 'Alternative road route ${index + 1}',
            isRecommended: index == 0,
            source: RouteDataSource.roadNetworkFallback,
            isTrafficAware: false,
          ),
        );
      }
    }
    return routes;
  }

  int _fallbackDurationSeconds({
    required TravelMode mode,
    required int distanceMeters,
    required int drivingSeconds,
  }) {
    switch (mode) {
      case TravelMode.driving:
        return math.max(60, drivingSeconds).toInt();
      case TravelMode.twoWheeler:
        final roadSpeedEstimate = distanceMeters / 7.5;
        return math.max(
          60,
          math.max(roadSpeedEstimate, drivingSeconds * 0.78).round(),
        ).toInt();
      case TravelMode.transit:
        final movingAndWaiting = distanceMeters / 5.0 + 5 * 60;
        return math.max(
          5 * 60,
          math.max(movingAndWaiting, drivingSeconds * 1.20 + 4 * 60)
              .round(),
        ).toInt();
      case TravelMode.walking:
        return math.max(60, (distanceMeters / 1.32).round()).toInt();
      case TravelMode.bicycling:
        return math.max(60, (distanceMeters / 4.2).round()).toInt();
    }
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  bool _isDeniedDirectionsResponse(
    int statusCode,
    Map<String, dynamic> decoded,
  ) {
    if (statusCode == 401 || statusCode == 403) return true;
    final status = decoded['status']?.toString();
    return status == 'REQUEST_DENIED';
  }

  String _googleErrorMessage(String body) {
    final decoded = _decodeObject(body);
    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      return error['message']?.toString() ?? '';
    }
    return decoded['error_message']?.toString() ?? '';
  }

  void _recordFailure(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty || _requestFailures.contains(compact)) return;
    _requestFailures.add(compact);
  }

  int _parseDurationSeconds(String? value) {
    if (value == null || !value.endsWith('s')) return 0;
    return double.tryParse(value.substring(0, value.length - 1))?.round() ?? 0;
  }
}

enum TravelMode { driving, twoWheeler, transit, walking, bicycling }

enum RouteDataSource {
  googleRoutes,
  googleDirections,
  roadNetworkFallback,
}

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

class RoutePlan {
  const RoutePlan({
    required this.estimates,
    required this.routes,
    this.hasLiveTraffic = false,
    this.usesFallbackRoutes = false,
  });

  final List<TravelEstimate> estimates;
  final List<TravelRoute> routes;
  final bool hasLiveTraffic;
  final bool usesFallbackRoutes;

  List<TravelRoute> routesFor(TravelMode mode) {
    final values = routes.where((route) => route.mode == mode).toList()
      ..sort((a, b) => a.duration.compareTo(b.duration));
    return values;
  }

  TravelRoute? shortestRouteFor(TravelMode mode) {
    final values = routesFor(mode);
    return values.isEmpty ? null : values.first;
  }
}

class TravelRoute {
  const TravelRoute({
    required this.id,
    required this.mode,
    required this.duration,
    required this.distanceMeters,
    required this.label,
    this.encodedPolyline,
    this.isRecommended = false,
    this.source = RouteDataSource.googleRoutes,
    this.isTrafficAware = false,
  });

  final String id;
  final TravelMode mode;
  final Duration duration;
  final int distanceMeters;
  final String label;
  final String? encodedPolyline;
  final bool isRecommended;
  final RouteDataSource source;
  final bool isTrafficAware;

  int get minutes => (duration.inSeconds / 60).ceil();

  String get durationText => formatTravelDuration(duration);

  String get distanceText => formatTravelDistance(distanceMeters);

  TravelEstimate toEstimate() => TravelEstimate(
        mode: mode,
        duration: duration,
        distanceMeters: distanceMeters,
        encodedPolyline: encodedPolyline,
        isTrafficAware: isTrafficAware,
        source: source,
      );
}

class TravelEstimate {
  const TravelEstimate({
    required this.mode,
    required this.duration,
    required this.distanceMeters,
    this.encodedPolyline,
    this.isTrafficAware = false,
    this.source = RouteDataSource.googleRoutes,
  });

  final TravelMode mode;
  final Duration duration;
  final int distanceMeters;
  final String? encodedPolyline;
  final bool isTrafficAware;
  final RouteDataSource source;

  int get minutes => (duration.inSeconds / 60).ceil();

  String get durationText => formatTravelDuration(duration);

  String get distanceText => formatTravelDistance(distanceMeters);

  String get notificationLine => '${mode.label}: $durationText';
}

String formatTravelDuration(Duration duration) {
  final value = (duration.inSeconds / 60).ceil();
  if (value < 60) return '$value min';
  final hours = value ~/ 60;
  final remaining = value % 60;
  return remaining == 0 ? '${hours} hr' : '${hours} hr ${remaining} min';
}

String formatTravelDistance(int distanceMeters) {
  if (distanceMeters < 1000) return '$distanceMeters m';
  return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
