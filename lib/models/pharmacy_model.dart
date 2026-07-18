/// Pharmacy Models

class Pharmacy {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phoneNumber;
  final String? website;
  final double? rating;
  final int? reviewCount;
  final List<String> availableMedications;
  final String? operatingHours;
  final bool isOpen;
  final String? imageUrl;
  final DateTime createdAt;

  Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phoneNumber,
    this.website,
    this.rating,
    this.reviewCount,
    required this.availableMedications,
    this.operatingHours,
    required this.isOpen,
    this.imageUrl,
    required this.createdAt,
  });

  factory Pharmacy.fromMap(Map<String, dynamic> map) {
    return Pharmacy(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      phoneNumber: map['phoneNumber'] ?? '',
      website: map['website'],
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      reviewCount: map['reviewCount'],
      availableMedications: List<String>.from(map['availableMedications'] ?? []),
      operatingHours: map['operatingHours'],
      isOpen: map['isOpen'] ?? true,
      imageUrl: map['imageUrl'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phoneNumber': phoneNumber,
      'website': website,
      'rating': rating,
      'reviewCount': reviewCount,
      'availableMedications': availableMedications,
      'operatingHours': operatingHours,
      'isOpen': isOpen,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Pharmacy(id: $id, name: $name, rating: $rating)';

  Pharmacy copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? phoneNumber,
    String? website,
    double? rating,
    int? reviewCount,
    List<String>? availableMedications,
    String? operatingHours,
    bool? isOpen,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return Pharmacy(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      availableMedications: availableMedications ?? this.availableMedications,
      operatingHours: operatingHours ?? this.operatingHours,
      isOpen: isOpen ?? this.isOpen,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
