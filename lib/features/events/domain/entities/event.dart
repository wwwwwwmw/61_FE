class Event {
  final int? id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String themeColor;
  final bool isAnnual;
  final String? eventType;
  final bool notificationEnabled;

  Event({
    this.id,
    required this.title,
    this.description,
    required this.eventDate,
    required this.themeColor,
    required this.isAnnual,
    this.eventType,
    this.notificationEnabled = true,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      eventDate: DateTime.parse(json['event_date']),
      themeColor: json['color'] ?? json['theme_color'] ?? '#FF5722',
      isAnnual: json['is_recurring'] == 1 ||
          json['is_recurring'] == true ||
          json['is_annual'] == true,
      eventType: json['event_type'],
      notificationEnabled: json['notification_enabled'] == 1 ||
          json['notification_enabled'] == true,
    );
  }

  get recurrencePattern => null;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'color': themeColor,
      'is_recurring': isAnnual,
      'event_type': eventType,
      'notification_enabled': notificationEnabled,
    };
  }
}
