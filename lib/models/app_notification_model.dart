class AppNotificationRecord {
  const AppNotificationRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.createdAt,
    this.type = 'medication',
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final String type;

  factory AppNotificationRecord.fromMap(Map<String, dynamic> map) {
    return AppNotificationRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      scheduledAt: DateTime.parse(map['scheduledAt']),
      createdAt: DateTime.parse(map['createdAt']),
      type: map['type'] ?? 'medication',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'scheduledAt': scheduledAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'type': type,
      };
}
