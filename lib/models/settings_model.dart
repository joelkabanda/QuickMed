/// Settings Model

class AppSettings {
  final String userId;
  final bool darkMode;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool reminderNotifications;
  final String appLanguage;
  final String dateFormat;
  final String timeFormat;
  final bool locationTracking;
  final String theme;
  final double textSize;
  final DateTime updatedAt;

  AppSettings({
    required this.userId,
    required this.darkMode,
    required this.pushNotifications,
    required this.emailNotifications,
    required this.reminderNotifications,
    required this.appLanguage,
    required this.dateFormat,
    required this.timeFormat,
    required this.locationTracking,
    required this.theme,
    required this.textSize,
    required this.updatedAt,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      userId: map['userId'] ?? '',
      darkMode: map['darkMode'] ?? false,
      pushNotifications: map['pushNotifications'] ?? true,
      emailNotifications: map['emailNotifications'] ?? true,
      reminderNotifications: map['reminderNotifications'] ?? true,
      appLanguage: map['appLanguage'] ?? 'en',
      dateFormat: map['dateFormat'] ?? 'MM/dd/yyyy',
      timeFormat: map['timeFormat'] ?? '12h',
      locationTracking: map['locationTracking'] ?? false,
      theme: map['theme'] ?? 'light',
      textSize: (map['textSize'] ?? 1.0).toDouble(),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'darkMode': darkMode,
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'reminderNotifications': reminderNotifications,
      'appLanguage': appLanguage,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
      'locationTracking': locationTracking,
      'theme': theme,
      'textSize': textSize,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'AppSettings(userId: $userId, darkMode: $darkMode, language: $appLanguage)';

  AppSettings copyWith({
    String? userId,
    bool? darkMode,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? reminderNotifications,
    String? appLanguage,
    String? dateFormat,
    String? timeFormat,
    bool? locationTracking,
    String? theme,
    double? textSize,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      userId: userId ?? this.userId,
      darkMode: darkMode ?? this.darkMode,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      reminderNotifications: reminderNotifications ?? this.reminderNotifications,
      appLanguage: appLanguage ?? this.appLanguage,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      locationTracking: locationTracking ?? this.locationTracking,
      theme: theme ?? this.theme,
      textSize: textSize ?? this.textSize,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
