import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/google_routes_service.dart';
import 'package:quickmed/services/location_service.dart';

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

class _LocationComparisonMapViewState extends State<LocationComparisonMapView> {
  late final MapController _mapController;
  late SavedPharmacyLocation _destination;
  final DatabaseService _database = DatabaseService();
  final GoogleRoutesService _routes = GoogleRoutesService();

  Position? _position;
  StreamSubscription<Position>? _positionSubscription;
  List<TravelEstimate> _estimates = const [];
  List<LatLng> _routePoints = const [];
  bool _loadingLocation = false;
  bool _loadingRoutes = false;
  bool _liveTracking = false;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _destination = widget.savedLocation;
    if (widget.showCurrentLocation) _loadCurrentLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) setState(() => _loadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() => _position = position);
      _fitMap();
      await _loadTravelEstimates();
    } catch (error) {
      if (mounted) {
        setState(() => _routeError = 'Location unavailable: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _loadTravelEstimates() async {
    final current = _position;
    if (current == null) return;

    if (mounted) {
      setState(() {
        _loadingRoutes = true;
        _routeError = null;
      });
    }

    try {
      final estimates = await _routes.getTravelEstimates(
        originLatitude: current.latitude,
        originLongitude: current.longitude,
        destinationLatitude: _destination.latitude,
        destinationLongitude: _destination.longitude,
      );
      final preferred = _pickRouteForPolyline(estimates);
      final decoded = preferred?.encodedPolyline == null
          ? const <LatLng>[]
          : _decodePolyline(preferred!.encodedPolyline!);

      if (!mounted) return;
      setState(() {
        _estimates = estimates;
        _routePoints = decoded;
      });
      _fitMap();
    } catch (error) {
      debugPrint('Google route loading failed: $error');
      if (!mounted) return;
      setState(() {
        _routeError = error.toString().replaceFirst('Bad state: ', '');
        _estimates = const [];
        _routePoints = const [];
      });
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  TravelEstimate? _pickRouteForPolyline(List<TravelEstimate> values) {
    for (final mode in [
      TravelMode.driving,
      TravelMode.twoWheeler,
      TravelMode.walking,
      TravelMode.bicycling,
      TravelMode.transit,
    ]) {
      for (final estimate in values) {
        if (estimate.mode == mode &&
            estimate.encodedPolyline?.isNotEmpty == true) {
          return estimate;
        }
      }
    }
    return null;
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

  void _fitMap() {
    final current = _position;
    if (current == null) {
      _mapController.move(
        LatLng(_destination.latitude, _destination.longitude),
        15,
      );
      return;
    }
    final bounds = LatLngBounds(
      LatLng(current.latitude, current.longitude),
      LatLng(_destination.latitude, _destination.longitude),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  void _toggleLiveTracking() {
    if (_liveTracking) {
      _positionSubscription?.cancel();
      setState(() => _liveTracking = false);
      return;
    }

    setState(() => _liveTracking = true);
    _positionSubscription = LocationService.getPositionStream(
      distanceFilter: 25,
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() => _position = position);
        _loadTravelEstimates();
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _liveTracking = false;
            _routeError = 'Live location error: $error';
          });
        }
      },
    );
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
    if (userId != null) await _database.saveSavedPharmacyLocation(userId, result);
    setState(() => _destination = result);
    await _loadTravelEstimates();
  }

  Future<void> _openInExternalMap() async {
    final maps = await MapLauncher.installedMaps;
    if (!mounted) return;
    if (maps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No map application is installed.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            for (final map in maps)
              ListTile(
                leading: const Icon(Icons.map_outlined, color: Colors.blue),
                title: Text(map.mapName),
                subtitle: const Text('Open driving directions'),
                onTap: () {
                  map.showDirections(
                    destination: Coords(
                      _destination.latitude,
                      _destination.longitude,
                    ),
                    destinationTitle: _destination.pharmacyName,
                    origin: _position == null
                        ? null
                        : Coords(
                            _position!.latitude,
                            _position!.longitude,
                          ),
                    directionsMode: DirectionsMode.driving,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final destinationPoint =
        LatLng(_destination.latitude, _destination.longitude);
    final current = _position;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(_destination.pharmacyName),
        actions: [
          IconButton(
            tooltip: 'Refresh travel times',
            onPressed: _loadingRoutes ? null : _loadTravelEstimates,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Edit destination',
            onPressed: _editLocation,
            icon: const Icon(Icons.edit_location_alt_outlined),
          ),
          IconButton(
            tooltip: _liveTracking ? 'Stop live tracking' : 'Track live location',
            onPressed: _toggleLiveTracking,
            icon: Icon(
              _liveTracking ? Icons.gps_fixed_rounded : Icons.gps_not_fixed,
              color: _liveTracking ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(center: destinationPoint, zoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.quickmed',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5,
                            color: Colors.blue,
                          ),
                        ],
                      )
                    else if (current != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(current.latitude, current.longitude),
                              destinationPoint,
                            ],
                            strokeWidth: 3,
                            color: Colors.blue.withOpacity(.45),
                            isDotted: true,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (current != null)
                          Marker(
                            point: LatLng(current.latitude, current.longitude),
                            width: 52,
                            height: 52,
                            child: const Icon(
                              Icons.my_location_rounded,
                              size: 38,
                              color: Colors.blue,
                            ),
                          ),
                        Marker(
                          point: destinationPoint,
                          width: 58,
                          height: 58,
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 48,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_loadingLocation || _loadingRoutes)
                  const Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: LinearProgressIndicator(minHeight: 4),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 340),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                  const Text('Destination', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    _destination.pharmacyName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _destination.address,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Travel time to destination',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_estimates.isNotEmpty)
                        Text(
                          _estimates.first.distanceText,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
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
                      child: Text(
                        _routeError!,
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    )
                  else if (_estimates.isEmpty && !_loadingRoutes)
                    const Text('No travel estimates are available for this route.')
                  else
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _estimates.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          final estimate = _estimates[index];
                          return Container(
                            width: 118,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F7FD),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_modeIcon(estimate.mode), color: Colors.blue),
                                const SizedBox(height: 5),
                                Text(
                                  estimate.durationText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  estimate.mode.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openInExternalMap,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Open Navigation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
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
