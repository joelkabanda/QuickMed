import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/google_routes_service.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/services/reminder_service.dart';

import 'location_picker_screen.dart';

class LocationComparisonMapView extends StatefulWidget {
  const LocationComparisonMapView({
    super.key,
    required this.savedLocation,
    this.showCurrentLocation = true,
  });

  final SavedPharmacyLocation savedLocation;
  final bool showCurrentLocation;

  @override
  State<LocationComparisonMapView> createState() =>
      _LocationComparisonMapViewState();
}

class _LocationComparisonMapViewState extends State<LocationComparisonMapView>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  late SavedPharmacyLocation _destination;
  final DatabaseService _database = DatabaseService();
  final GoogleRoutesService _routes = GoogleRoutesService();

  Position? _position;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _trafficRefreshTimer;
  RoutePlan? _routePlan;
  TravelMode _selectedMode = TravelMode.driving;
  String? _selectedRouteId;
  DateTime? _lastUpdatedAt;
  DateTime? _lastRouteRequestAt;
  String? _lastReminderRouteSignature;
  bool _loadingLocation = false;
  bool _loadingRoutes = false;
  bool _liveTracking = true;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _destination = widget.savedLocation;
    if (widget.showCurrentLocation) {
      _loadCurrentLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _trafficRefreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _liveTracking) {
      _startLiveUpdates();
      _loadRoutePlan();
    }
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) setState(() => _loadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() => _position = position);
      await _loadRoutePlan();
      _startLiveUpdates();
    } catch (error) {
      if (mounted) {
        setState(() => _routeError = 'Location unavailable: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _startLiveUpdates() {
    _positionSubscription?.cancel();
    _trafficRefreshTimer?.cancel();
    if (!_liveTracking) return;

    _positionSubscription = LocationService.getPositionStream(
      distanceFilter: 20,
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() => _position = position);
        _refreshRoutesThrottled();
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _liveTracking = false;
          _routeError = 'Live location error: $error';
        });
      },
    );

    // Traffic-aware travel times are refreshed while this screen is active.
    _trafficRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadRoutePlan(),
    );
  }

  void _refreshRoutesThrottled() {
    final last = _lastRouteRequestAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _loadRoutePlan();
  }

  Future<void> _loadRoutePlan() async {
    final current = _position;
    if (current == null || _loadingRoutes) return;

    _lastRouteRequestAt = DateTime.now();
    if (mounted) {
      setState(() {
        _loadingRoutes = true;
        _routeError = null;
      });
    }

    try {
      final plan = await _routes.getRoutePlan(
        originLatitude: current.latitude,
        originLongitude: current.longitude,
        destinationLatitude: _destination.latitude,
        destinationLongitude: _destination.longitude,
      );

      if (!mounted) return;
      var selectedMode = _selectedMode;
      if (plan.routesFor(selectedMode).isEmpty && plan.estimates.isNotEmpty) {
        selectedMode = plan.estimates.first.mode;
      }
      final selectedRoute = plan.shortestRouteFor(selectedMode);

      setState(() {
        _routePlan = plan;
        _selectedMode = selectedMode;
        _selectedRouteId = selectedRoute?.id;
        _lastUpdatedAt = DateTime.now();
      });
      await _fitMap();
      _refreshUpcomingReminderThresholds(plan.estimates);
    } catch (error) {
      debugPrint('Route loading failed: $error');
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      setState(() {
        // Do not remove a valid blue route merely because a later live refresh
        // encountered a temporary DNS or mobile-network failure.
        if (_routePlan == null) _routeError = message;
      });
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  void _refreshUpcomingReminderThresholds(List<TravelEstimate> estimates) {
    if (estimates.isEmpty) return;
    final ordered = [...estimates]
      ..sort((a, b) => a.duration.compareTo(b.duration));
    final walking = ordered.where((item) => item.mode == TravelMode.walking);
    final slowestForReminder = walking.isNotEmpty ? walking.first : ordered.last;
    final signature = '${ordered.first.mode.name}:${ordered.first.minutes}:'
        '${slowestForReminder.mode.name}:${slowestForReminder.minutes}:'
        '${_destination.pharmacyId}';
    if (_lastReminderRouteSignature == signature) return;
    _lastReminderRouteSignature = signature;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    unawaited(
      ReminderService.refreshUpcomingMedicationNotificationsForUser(
        userId: userId,
        destinationName: _destination.pharmacyName,
        travelEstimates: estimates,
      ),
    );
  }

  List<TravelRoute> get _visibleRoutes {
    return _routePlan?.routesFor(_selectedMode) ?? const <TravelRoute>[];
  }

  TravelRoute? get _selectedRoute {
    final routes = _visibleRoutes;
    if (routes.isEmpty) return null;
    for (final route in routes) {
      if (route.id == _selectedRouteId) return route;
    }
    return routes.first;
  }

  Set<Polyline> _buildPolylines() {
    final result = <Polyline>{};
    final routes = _visibleRoutes;

    for (final route in routes.reversed) {
      final encoded = route.encodedPolyline?.trim() ?? '';
      if (encoded.isEmpty) continue;
      final points = _decodePolyline(encoded);
      if (points.length < 2) continue;
      final selected = route.id == _selectedRoute?.id;

      if (selected) {
        // A dark outline under the route makes the active path clear against
        // roads and buildings, while the blue line marks the route to follow.
        result.add(
          Polyline(
            polylineId: PolylineId('${route.id}_outline'),
            points: points,
            width: 13,
            color: const Color(0xFF17206E),
            zIndex: 9,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
        result.add(
          Polyline(
            polylineId: PolylineId('${route.id}_selected'),
            points: points,
            width: 9,
            color: const Color(0xFF1647F5),
            zIndex: 10,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
            patterns: const [],
            consumeTapEvents: true,
            onTap: () {
              if (!mounted) return;
              setState(() => _selectedRouteId = route.id);
            },
          ),
        );
      } else {
        result.add(
          Polyline(
            polylineId: PolylineId('${route.id}_alternative'),
            points: points,
            width: 5,
            color: Colors.blueGrey.withOpacity(.42),
            zIndex: 1,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
            patterns: const [],
            consumeTapEvents: true,
            onTap: () {
              if (!mounted) return;
              setState(() => _selectedRouteId = route.id);
            },
          ),
        );
      }
    }
    return result;
  }

  Set<Marker> _buildMarkers() {
    final destination = LatLng(
      _destination.latitude,
      _destination.longitude,
    );
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: _destination.pharmacyName,
          snippet: _destination.address,
        ),
      ),
    };

    final current = _position;
    if (current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(current.latitude, current.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Current location'),
        ),
      );
    }

    // No duration or time markers are placed on top of the route. Travel times
    // remain in the information panel below the map.
    return markers;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(latitude / 1E5, longitude / 1E5));
    }
    return points;
  }

  Future<void> _fitMap() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[
      LatLng(_destination.latitude, _destination.longitude),
      if (_position != null)
        LatLng(_position!.latitude, _position!.longitude),
    ];
    final route = _selectedRoute;
    if (route?.encodedPolyline?.isNotEmpty == true) {
      points.addAll(_decodePolyline(route!.encodedPolyline!));
    }
    if (points.isEmpty) return;

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  void _toggleLiveTracking() {
    setState(() => _liveTracking = !_liveTracking);
    if (_liveTracking) {
      _startLiveUpdates();
      _loadRoutePlan();
    } else {
      _positionSubscription?.cancel();
      _trafficRefreshTimer?.cancel();
    }
  }

  Future<void> _editLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: _destination),
      ),
    );
    if (result is! SavedPharmacyLocation || !mounted) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _database.saveSavedPharmacyLocation(userId, result);
    }
    setState(() {
      _destination = result;
      _selectedRouteId = null;
      _lastReminderRouteSignature = null;
    });
    await _loadRoutePlan();
  }

  IconData _modeIcon(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return Icons.directions_car_rounded;
      case TravelMode.twoWheeler:
        return Icons.two_wheeler_rounded;
      case TravelMode.transit:
        return Icons.directions_bus_rounded;
      case TravelMode.walking:
        return Icons.directions_walk_rounded;
      case TravelMode.bicycling:
        return Icons.directions_bike_rounded;
    }
  }

  String _updatedText() {
    final value = _lastUpdatedAt;
    if (value == null) return 'Loading road route';
    final minute = value.minute.toString().padLeft(2, '0');
    final prefix = _routePlan?.hasLiveTraffic == true
        ? 'Live traffic'
        : 'Road route';
    return '$prefix • ${value.hour}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final destinationPoint = LatLng(
      _destination.latitude,
      _destination.longitude,
    );
    final estimates = _routePlan?.estimates ?? const <TravelEstimate>[];
    final visibleRoutes = _visibleRoutes;
    final selectedRoute = _selectedRoute;
    final routeStatusColor = _routePlan?.hasLiveTraffic == true
        ? Colors.green
        : Colors.blueGrey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(_destination.pharmacyName),
        actions: [
          IconButton(
            tooltip: 'Refresh live routes',
            onPressed: _loadingRoutes ? null : _loadRoutePlan,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Edit destination',
            onPressed: _editLocation,
            icon: const Icon(Icons.edit_location_alt_outlined),
          ),
          IconButton(
            tooltip: _liveTracking ? 'Stop live tracking' : 'Start live tracking',
            onPressed: _toggleLiveTracking,
            icon: Icon(
              _liveTracking ? Icons.gps_fixed_rounded : Icons.gps_not_fixed,
              color: _liveTracking ? Colors.blue : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: destinationPoint,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitMap();
                  },
                  mapType: MapType.normal,
                  myLocationEnabled: _position != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  trafficEnabled: true,
                  compassEnabled: true,
                  buildingsEnabled: true,
                  markers: _buildMarkers(),
                  polylines: _buildPolylines(),
                ),
                if (_loadingLocation || _loadingRoutes)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 4),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_route_map',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    onPressed: _fitMap,
                    child: const Icon(Icons.center_focus_strong_rounded),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 355),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 14,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _destination.pharmacyName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: routeStatusColor.withOpacity(.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _updatedText(),
                          style: TextStyle(
                            color: routeStatusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _destination.address,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Travel time by transport',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_routeError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.orange.shade900,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _routeError!,
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadingRoutes ? null : _loadRoutePlan,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (estimates.isEmpty && !_loadingRoutes)
                    const Text('No travel estimates are available for this route.')
                  else
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: estimates.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          final estimate = estimates[index];
                          final selected = estimate.mode == _selectedMode;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              final shortest =
                                  _routePlan?.shortestRouteFor(estimate.mode);
                              setState(() {
                                _selectedMode = estimate.mode;
                                _selectedRouteId = shortest?.id;
                              });
                              _fitMap();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 124,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? Colors.blue
                                      : Colors.grey.shade200,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _modeIcon(estimate.mode),
                                    color: selected ? Colors.blue : Colors.black54,
                                  ),
                                  const Spacer(),
                                  Text(
                                    estimate.mode.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    estimate.durationText,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (visibleRoutes.length > 1) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Available routes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: visibleRoutes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final route = visibleRoutes[index];
                          final selected = route.id == selectedRoute?.id;
                          return ChoiceChip(
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedRouteId = route.id);
                              _fitMap();
                            },
                            label: Text(
                              'Route ${index + 1} • ${route.durationText}',
                            ),
                            backgroundColor: Colors.grey.shade50,
                            selectedColor: Colors.blue.shade50,
                            side: BorderSide(
                              color: selected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (selectedRoute != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.route_rounded, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${selectedRoute.label}: '
                              '${selectedRoute.durationText}, '
                              '${selectedRoute.distanceText}. '
                              'The selected route is shown with a thick blue line.',
                              style: TextStyle(color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_routePlan?.usesFallbackRoutes == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'The blue track follows the road. Google live traffic was '
                        'not available for every transport mode, so the missing '
                        'times are road-distance estimates.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _routePlan?.hasLiveTraffic == true
                        ? 'Navigation stays inside QuickMed. Route times refresh '
                            'from the current location and Google live traffic.'
                        : 'Navigation stays inside QuickMed. The road route refreshes '
                            'from the current location while this screen is open.',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
