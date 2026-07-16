/// Medication Models

class Medication {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String frequency;
  final String? description;
  final String? prescribedBy;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> sideEffects;
  final bool isActive;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.description,
    this.prescribedBy,
    required this.startDate,
    this.endDate,
    required this.sideEffects,
    required this.isActive,
    required this.createdAt,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      description: map['description'],
      prescribedBy: map['prescribedBy'],
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      sideEffects: List<String>.from(map['sideEffects'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'description': description,
      'prescribedBy': prescribedBy,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'sideEffects': sideEffects,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Medication(id: $id, name: $name, dosage: $dosage)';

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    String? frequency,
    String? description,
    String? prescribedBy,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? sideEffects,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      description: description ?? this.description,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sideEffects: sideEffects ?? this.sideEffects,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
