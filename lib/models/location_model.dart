/// Location and Maps Models

class Location {
  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final String? city;
  final String? country;
  final String? postalCode;
  final DateTime createdAt;

  Location({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city,
    this.country,
    this.postalCode,
    required this.createdAt,
  });

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? '',
      city: map['city'],
      country: map['country'],
      postalCode: map['postalCode'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
      'postalCode': postalCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Location(id: $id, address: $address, city: $city)';
}

class Route {
  final String id;
  final Location origin;
  final Location destination;
  final double distance;
  final Duration estimatedTime;
  final String transportMode;
  final List<Location> waypoints;
  final String? instructions;

  Route({
    required this.id,
    required this.origin,
    required this.destination,
    required this.distance,
    required this.estimatedTime,
    required this.transportMode,
    required this.waypoints,
    this.instructions,
  });

  factory Route.fromMap(Map<String, dynamic> map) {
    return Route(
      id: map['id'] ?? '',
      origin: Location.fromMap(map['origin'] ?? {}),
      destination: Location.fromMap(map['destination'] ?? {}),
      distance: (map['distance'] ?? 0.0).toDouble(),
      estimatedTime: Duration(minutes: map['estimatedTime'] ?? 0),
      transportMode: map['transportMode'] ?? 'driving',
      waypoints: (map['waypoints'] as List<dynamic>?)
              ?.map((w) => Location.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: map['instructions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'distance': distance,
      'estimatedTime': estimatedTime.inMinutes,
      'transportMode': transportMode,
      'waypoints': waypoints.map((w) => w.toMap()).toList(),
      'instructions': instructions,
    };
  }

  @override
  String toString() =>
      'Route(id: $id, distance: $distance km, time: ${estimatedTime.inMinutes} min)';
}
