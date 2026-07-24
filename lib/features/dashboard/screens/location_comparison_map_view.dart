import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_launcher/map_launcher.dart';
import 'location_picker_screen.dart';

class LocationComparisonMapView extends StatefulWidget {
  final SavedPharmacyLocation savedLocation;
  final bool showCurrentLocation;

  const LocationComparisonMapView({
    super.key,
    required this.savedLocation,
    this.showCurrentLocation = true,
  });

  @override
  State<LocationComparisonMapView> createState() =>
      _LocationComparisonMapViewState();
}

class _LocationComparisonMapViewState extends State<LocationComparisonMapView> {
  late MapController _mapController;
  late SavedPharmacyLocation _currentSavedLocation;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isLoadingRoute = false;
  String? _distanceText;
  String? _timeText;
  int? _distanceMeters;
  List<Map<String, double>> _routeCoordinates = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _enableRealTimeTracking = false;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentSavedLocation = widget.savedLocation;
    if (widget.showCurrentLocation) {
      _loadCurrentLocation();
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() => _currentPosition = position);
        _calculateDistance();
        _loadRoute();

        _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          13,
        );
      }
    } catch (e) {
      debugPrint('Error loading location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _loadRoute() async {
    if (_currentPosition == null) return;

    setState(() => _isLoadingRoute = true);
    try {
      // Get all route info (coordinates + stats) in one go to keep them in perfect sync
      final routeInfo = await LocationService.getFullRouteInfo(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentSavedLocation.latitude,
        _currentSavedLocation.longitude,
      );

      if (mounted) {
        setState(() {
          _routeCoordinates = routeInfo['coordinates'];
          _distanceText = routeInfo['distanceText'];
          _timeText = routeInfo['durationText'];
          _distanceMeters = (routeInfo['distance'] * 1000).toInt();
        });
      }
    } catch (e) {
      debugPrint('Error loading route: $e');
      // If routing fails, we keep the simple Haversine calculation as fallback
      _calculateDistance();
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  void _calculateDistance() {
    if (_currentPosition == null) return;

    final result = LocationService.calculateDistanceAndTime(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _currentSavedLocation.latitude,
      _currentSavedLocation.longitude,
    );

    if (mounted) {
      setState(() {
        _distanceText = result['distanceText'];
        _timeText = result['timeText'];
        _distanceMeters = (result['distance'] * 1000).toInt();
      });
    }
  }

  void _toggleRealTimeTracking() {
    if (_enableRealTimeTracking) {
      _positionStreamSubscription?.cancel();
      setState(() => _enableRealTimeTracking = false);
    } else {
      _startRealTimeTracking();
    }
  }

  void _startRealTimeTracking() {
    setState(() => _enableRealTimeTracking = true);
    
    _positionStreamSubscription = LocationService.getPositionStream(
      distanceFilter: 15, // Update every 15 meters to balance accuracy and API usage
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          
          // 1. Immediately update fast straight-line estimates
          _calculateDistance();
          
          // 2. Update accurate route and walking time
          _loadRoute();
          
          // 3. Keep the map centered on the user during tracking
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            _mapController.zoom,
          );
        }
      },
      onError: (error) {
        debugPrint('Position stream error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location tracking error: $error')),
          );
          setState(() => _enableRealTimeTracking = false);
        }
      },
    );
  }

  Future<void> _openInExternalMap() async {
    try {
      final coords = Coords(
        _currentSavedLocation.latitude,
        _currentSavedLocation.longitude,
      );

      final availableMaps = await MapLauncher.installedMaps;

      if (!mounted) return;

      if (availableMaps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No maps application found')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Wrap(
                children: <Widget>[
                  for (final map in availableMaps)
                    ListTile(
                      onTap: () {
                        if (_currentPosition != null) {
                          map.showDirections(
                            destination: coords,
                            destinationTitle: _currentSavedLocation.pharmacyName,
                            origin: Coords(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            directionsMode: DirectionsMode.walking,
                          );
                        } else {
                          map.showMarker(
                            coords: coords,
                            title: _currentSavedLocation.pharmacyName,
                            description: _currentSavedLocation.address,
                          );
                        }
                        Navigator.of(context).pop();
                      },
                      title: Text(map.mapName),
                      leading: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.map,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening map: $e')),
        );
      }
    }
  }

  Future<void> _editLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _currentSavedLocation,
        ),
      ),
    );

    if (result is SavedPharmacyLocation && mounted) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _dbService.saveSavedPharmacyLocation(uid, result);
        setState(() {
          _currentSavedLocation = result;
          _routeCoordinates = []; // Reset route
          _loadRoute(); // Reload route to updated location
          _calculateDistance();
          _mapController.move(
            LatLng(_currentSavedLocation.latitude, _currentSavedLocation.longitude),
            15,
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location updated successfully')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userLocation = _currentPosition;
    final savedLatLng = LatLng(
        _currentSavedLocation.latitude, _currentSavedLocation.longitude);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentSavedLocation.pharmacyName,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on, color: Colors.green),
            onPressed: _editLocation,
            tooltip: 'Edit destination',
          ),
          if (_enableRealTimeTracking)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Tooltip(
                  message: 'Stop live tracking',
                  child: ElevatedButton.icon(
                    onPressed: _toggleRealTimeTracking,
                    icon: const Icon(Icons.gps_fixed, size: 16),
                    label: const Text('LIVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.gps_not_fixed, color: Colors.grey),
              onPressed: _toggleRealTimeTracking,
              tooltip: 'Enable live tracking',
            ),
          IconButton(
            icon: const Icon(Icons.navigation, color: Colors.blue),
            onPressed: _openInExternalMap,
            tooltip: 'Open in Maps',
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
                  options: MapOptions(
                    center: savedLatLng,
                    zoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.quickmed.app',
                    ),
                    if (userLocation != null && _routeCoordinates.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routeCoordinates
                                .map((coord) =>
                                    LatLng(coord['latitude']!, coord['longitude']!))
                                .toList(),
                            color: Colors.blue,
                            strokeWidth: 4,
                          ),
                        ],
                      )
                    else if (userLocation != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(userLocation.latitude,
                                  userLocation.longitude),
                              savedLatLng,
                            ],
                            color: Colors.blue.withValues(alpha: 0.5),
                            strokeWidth: 2,
                            isDotted: true,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (userLocation != null)
                          Marker(
                            point: LatLng(
                              userLocation.latitude,
                              userLocation.longitude,
                            ),
                            width: 80,
                            height: 80,
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _enableRealTimeTracking
                                        ? Colors.red
                                        : Colors.blue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'St • ${_distanceText ?? ""}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _enableRealTimeTracking
                                        ? Colors.red
                                        : Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Marker(
                          point: savedLatLng,
                          width: 80,
                          height: 80,
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'En • ${_timeText ?? ""}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isLoadingLocation || _isLoadingRoute)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isLoadingRoute ? 'Loading route...' : 'Loading location...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destination',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentSavedLocation.pharmacyName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_distanceText != null && _timeText != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _distanceText!,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_walk, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  _timeText!,
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currentSavedLocation.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openInExternalMap,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Open Navigation'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
