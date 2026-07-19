/// Medication Models

class Medication {
  final String id;
  final String userId;
  final String name;
  final String type; // e.g., Tablet, Capsule, Liquid, Injection
  final String dosage;
  final String frequency;
  final List<String> scheduleTimes; // e.g., ["08:00", "14:00", "20:00"]
  final String? description;
  final String? prescribedBy;
  final String? pharmacyPharmacyId; // Where to get the medication from
  final String? pharmacyAddress;
  final String? sideEffects; // Comma-separated side effects
  final int? quantity; // Number of pills/units
  final String? purpose; // Why taking this medication
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> reminderTimes; // Times to be reminded
  final bool isActive;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.dosage,
    required this.frequency,
    required this.scheduleTimes,
    this.description,
    this.prescribedBy,
    this.pharmacyPharmacyId,
    this.pharmacyAddress,
    this.sideEffects,
    this.quantity,
    this.purpose,
    required this.startDate,
    this.endDate,
    required this.reminderTimes,
    required this.isActive,
    required this.createdAt,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'Tablet',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      scheduleTimes: List<String>.from(map['scheduleTimes'] ?? []),
      description: map['description'],
      prescribedBy: map['prescribedBy'],
      pharmacyPharmacyId: map['pharmacyPharmacyId'],
      pharmacyAddress: map['pharmacyAddress'],
      sideEffects: map['sideEffects'],
      quantity: map['quantity'],
      purpose: map['purpose'],
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      reminderTimes: List<String>.from(map['reminderTimes'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type,
      'dosage': dosage,
      'frequency': frequency,
      'scheduleTimes': scheduleTimes,
      'description': description,
      'prescribedBy': prescribedBy,
      'pharmacyPharmacyId': pharmacyPharmacyId,
      'pharmacyAddress': pharmacyAddress,
      'sideEffects': sideEffects,
      'quantity': quantity,
      'purpose': purpose,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'reminderTimes': reminderTimes,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Medication(id: $id, name: $name, dosage: $dosage, type: $type)';

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? dosage,
    String? frequency,
    List<String>? scheduleTimes,
    String? description,
    String? prescribedBy,
    String? pharmacyPharmacyId,
    String? pharmacyAddress,
    String? sideEffects,
    int? quantity,
    String? purpose,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? reminderTimes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      description: description ?? this.description,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      pharmacyPharmacyId: pharmacyPharmacyId ?? this.pharmacyPharmacyId,
      pharmacyAddress: pharmacyAddress ?? this.pharmacyAddress,
      sideEffects: sideEffects ?? this.sideEffects,
      quantity: quantity ?? this.quantity,
      purpose: purpose ?? this.purpose,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
