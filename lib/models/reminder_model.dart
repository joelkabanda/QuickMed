/// Reminder Models
library;

enum ReminderStatus { pending, taken, missed, skipped }

class Reminder {
  final String id;
  final String userId;
  final String medicationId;
  final DateTime reminderTime;
  final ReminderStatus status;
  final String? notificationId;
  final bool isNotificationSent;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.medicationId,
    required this.reminderTime,
    required this.status,
    this.notificationId,
    required this.isNotificationSent,
    this.completedAt,
    this.notes,
    required this.createdAt,
  });

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      medicationId: map['medicationId'] ?? '',
      reminderTime: DateTime.parse(map['reminderTime'] ?? DateTime.now().toIso8601String()),
      status: ReminderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['status'] ?? 'pending'),
        orElse: () => ReminderStatus.pending,
      ),
      notificationId: map['notificationId'],
      isNotificationSent: map['isNotificationSent'] ?? false,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'medicationId': medicationId,
      'reminderTime': reminderTime.toIso8601String(),
      'status': status.toString().split('.').last,
      'notificationId': notificationId,
      'isNotificationSent': isNotificationSent,
      'completedAt': completedAt?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'Reminder(id: $id, medicationId: $medicationId, status: $status)';

  Reminder copyWith({
    String? id,
    String? userId,
    String? medicationId,
    DateTime? reminderTime,
    ReminderStatus? status,
    String? notificationId,
    bool? isNotificationSent,
    DateTime? completedAt,
    String? notes,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicationId: medicationId ?? this.medicationId,
      reminderTime: reminderTime ?? this.reminderTime,
      status: status ?? this.status,
      notificationId: notificationId ?? this.notificationId,
      isNotificationSent: isNotificationSent ?? this.isNotificationSent,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
