class Event {
  final int? id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String themeColor;
  final bool isAnnual;
  final String? eventType;
  final bool notificationEnabled;
  final String? recurrencePattern; // 'daily' | 'weekly' | 'monthly' | 'yearly'

  Event({
    this.id,
    required this.title,
    this.description,
    required this.eventDate,
    required this.themeColor,
    required this.isAnnual,
    this.eventType,
    this.notificationEnabled = true,
    this.recurrencePattern,
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
      recurrencePattern: json['recurrence_pattern'],
    );
  }

  /// Compute the next occurrence time after [now] for recurring countdowns.
  /// If not recurring, returns [eventDate]. Supports 'daily' and 'weekly' robustly,
  /// falls back to adding months/years for 'monthly'/'yearly'.
  DateTime nextOccurrenceAfter(DateTime now) {
    if (!(isAnnual == true || (recurrencePattern != null))) {
      return eventDate;
    }

    final pattern = recurrencePattern;
    // If target already in future, keep it
    if (eventDate.isAfter(now)) return eventDate;

    DateTime next = eventDate;
    switch (pattern) {
      case 'daily':
        // Add days until it's in the future
        while (!next.isAfter(now)) {
          next = next.add(const Duration(days: 1));
        }
        break;
      case 'weekly':
        while (!next.isAfter(now)) {
          next = next.add(const Duration(days: 7));
        }
        break;
      case 'monthly':
        while (!next.isAfter(now)) {
          next = DateTime(next.year, next.month + 1, next.day, next.hour,
              next.minute, next.second);
        }
        break;
      case 'yearly':
        while (!next.isAfter(now)) {
          next = DateTime(next.year + 1, next.month, next.day, next.hour,
              next.minute, next.second);
        }
        break;
      default:
        // If unknown, treat as one-shot
        break;
    }
    return next;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'color': themeColor,
      'is_recurring': isAnnual,
      'event_type': eventType,
      'notification_enabled': notificationEnabled,
      'recurrence_pattern': recurrencePattern,
    };
  }
}
