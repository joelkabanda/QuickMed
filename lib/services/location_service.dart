import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static const double meterToKm = 0.001;
  static const double avgSpeedKmH = 2.5; // Significantly reduced speed to increase estimated travel time (approx 40m/min)
  static Stream<Position>? _positionStream;

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permissions
  static Future<LocationPermission> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Check current permission status
  static Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Get current user location
  static Future<Position> getCurrentLocation() async {
    try {
      final permission = await checkLocationPermission();
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable in app settings.');
      }

      if (permission == LocationPermission.denied) {
        final newPermission = await requestLocationPermission();
        if (newPermission == LocationPermission.denied ||
            newPermission == LocationPermission.deniedForever) {
          throw Exception('Location permission denied by user.');
        }
      }

      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        throw Exception('Location services are disabled on your device. Please enable them in settings.');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  /// Calculate distance between two points in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double radiusOfEarth = 6371; // Radius of the earth in km
    final double latDistance = _degreesToRadians(lat2 - lat1);
    final double lonDistance = _degreesToRadians(lon2 - lon1);
    final double a = sin(latDistance / 2) * sin(latDistance / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(lonDistance / 2) *
            sin(lonDistance / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radiusOfEarth * c;
  }

  /// Calculate estimated time to reach destination in minutes
  static int calculateEstimatedTimeMinutes(double distanceKm) {
    return ((distanceKm / avgSpeedKmH) * 60).ceil();
  }

  /// Calculate both distance and estimated time
  static Map<String, dynamic> calculateDistanceAndTime(
    double userLat,
    double userLon,
    double destLat,
    double destLon,
  ) {
    final distance = calculateDistance(userLat, userLon, destLat, destLon);
    final timeMinutes = calculateEstimatedTimeMinutes(distance);

    return {
      'distance': distance,
      'distanceText': _formatDistanceText(distance),
      'timeMinutes': timeMinutes,
      'timeText': _formatTimeText(timeMinutes),
    };
  }

  static String _formatDistanceText(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  /// Get address from coordinates
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks =
          await geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';
      }
      return '$latitude, $longitude';
    } catch (e) {
      return '$latitude, $longitude';
    }
  }

  /// Get coordinates from address
  static Future<List<geocoding.Location>> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      return await geocoding.locationFromAddress(address);
    } catch (e) {
      throw Exception('Failed to get coordinates from address: $e');
    }
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  static String _formatTimeText(int minutes) {
    if (minutes < 1) {
      return 'Arriving now';
    } else if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours hr${hours > 1 ? 's' : ''}';
      }
      return '$hours hr $mins min';
    }
  }

  /// Get real-time position stream for continuous location tracking
  static Stream<Position> getPositionStream({
    int distanceFilter = 10,
    int intervalDuration = 1000,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        timeLimit: const Duration(seconds: 10),
      ),
    );
  }

  /// Calculate distance and time together
  static Future<Map<String, dynamic>> calculateDistanceAndTimeAsync(
    double userLat,
    double userLon,
    double destLat,
    double destLon,
  ) async {
    return calculateDistanceAndTime(userLat, userLon, destLat, destLon);
  }

  /// Get route coordinates from OSRM (Open Source Routing Machine)
  static Future<List<Map<String, double>>> getRouteCoordinates(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) async {
    try {
      final info = await getFullRouteInfo(startLat, startLon, endLat, endLon);
      return info['coordinates'];
    } catch (e) {
      throw Exception('Error getting route: $e');
    }
  }

  /// Get route details including distance and duration
  static Future<Map<String, dynamic>> getRouteDetails(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) async {
    try {
      return await getFullRouteInfo(startLat, startLon, endLat, endLon);
    } catch (e) {
      throw Exception('Error getting route details: $e');
    }
  }

  /// Get full route information including coordinates, distance, and duration
  static Future<Map<String, dynamic>> getFullRouteInfo(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/foot/$startLon,$startLat;$endLon,$endLat?geometries=geojson&overview=full';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Route request timeout'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final routes = json['routes'] as List;

        if (routes.isEmpty) {
          throw Exception('No route found');
        }

        final route = routes[0];
        final distance = (route['distance'] as num).toDouble();
        final duration = (route['duration'] as num).toDouble();
        
        final geometry = route['geometry'];
        final coordinates = (geometry['coordinates'] as List)
            .map((coord) => {
                  'latitude': coord[1] as double,
                  'longitude': coord[0] as double,
                })
            .toList();

        return {
          'coordinates': coordinates,
          'distance': distance / 1000,
          'distanceText': _formatDistanceText(distance / 1000),
          'duration': duration.toInt(),
          'durationText': _formatDurationText(duration.toInt()),
        };
      } else {
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting route info: $e');
    }
  }

  static String _formatDurationText(int seconds) {
    // We add a 100% buffer (multiplier of 2.0) to OSRM's raw 5km/h duration 
    // to reflect a much slower 2.5km/h walking pace and account for city delays.
    final adjustedMinutes = ((seconds / 60) * 2.0).round();
    
    if (adjustedMinutes < 1) {
      return '1 min';
    } else if (adjustedMinutes < 60) {
      return '$adjustedMinutes min';
    } else {
      final hours = adjustedMinutes ~/ 60;
      final remainingMinutes = adjustedMinutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hr${hours > 1 ? 's' : ''}';
      }
      return '$hours hr $remainingMinutes min';
    }
  }
}
