/// User Profile Model

class UserProfile {
  final String userId;
  final String? bio;
  final String? dateOfBirth;
  final String? gender;
  final String? bloodType;
  final String? emergencyContact;
  final String? emergencyContactPhone;
  final List<String>? allergies;
  final List<String>? medicalConditions;
  final String? profileImageUrl;
  final String? preferredLanguage;
  final String? timezone;
  final bool notificationsEnabled;
  final DateTime updatedAt;

  UserProfile({
    required this.userId,
    this.bio,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.emergencyContact,
    this.emergencyContactPhone,
    this.allergies,
    this.medicalConditions,
    this.profileImageUrl,
    this.preferredLanguage,
    this.timezone,
    required this.notificationsEnabled,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      bio: map['bio'],
      dateOfBirth: map['dateOfBirth'],
      gender: map['gender'],
      bloodType: map['bloodType'],
      emergencyContact: map['emergencyContact'],
      emergencyContactPhone: map['emergencyContactPhone'],
      allergies: List<String>.from(map['allergies'] ?? []),
      medicalConditions: List<String>.from(map['medicalConditions'] ?? []),
      profileImageUrl: map['profileImageUrl'],
      preferredLanguage: map['preferredLanguage'],
      timezone: map['timezone'],
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bio': bio,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'bloodType': bloodType,
      'emergencyContact': emergencyContact,
      'emergencyContactPhone': emergencyContactPhone,
      'allergies': allergies,
      'medicalConditions': medicalConditions,
      'profileImageUrl': profileImageUrl,
      'preferredLanguage': preferredLanguage,
      'timezone': timezone,
      'notificationsEnabled': notificationsEnabled,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'UserProfile(userId: $userId, bloodType: $bloodType)';

  UserProfile copyWith({
    String? userId,
    String? bio,
    String? dateOfBirth,
    String? gender,
    String? bloodType,
    String? emergencyContact,
    String? emergencyContactPhone,
    List<String>? allergies,
    List<String>? medicalConditions,
    String? profileImageUrl,
    String? preferredLanguage,
    String? timezone,
    bool? notificationsEnabled,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      bio: bio ?? this.bio,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      timezone: timezone ?? this.timezone,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
