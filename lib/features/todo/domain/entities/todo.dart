import 'package:equatable/equatable.dart';

class Todo extends Equatable {
  final int? id;
  final String? clientId;
  final String title;
  final String? description;
  final bool isCompleted;
  final int? categoryId;
  final String priority;
  final List<String> tags;
  final DateTime? dueDate;
  final DateTime? reminderTime;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isSynced;
  final int version;
  
  const Todo({
    this.id,
    this.clientId,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.categoryId,
    this.priority = 'medium',
    this.tags = const [],
    this.dueDate,
    this.reminderTime,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
    this.version = 1,
  });
  
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      clientId: json['client_id'],
      title: json['title'],
      description: json['description'],
      isCompleted: json['is_completed'] is int 
          ? json['is_completed'] == 1 
          : json['is_completed'] ?? false,
      categoryId: json['category_id'],
      priority: json['priority'] ?? 'medium',
      tags: json['tags'] != null
          ? (json['tags'] is String
              ? (json['tags'] as String).split(',')
              : List<String>.from(json['tags']))
          : [],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']).toLocal() : null,
      reminderTime: json['reminder_time'] != null ? DateTime.parse(json['reminder_time']).toLocal() : null,
      position: json['position'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isDeleted: json['is_deleted'] is int 
          ? json['is_deleted'] == 1 
          : json['is_deleted'] ?? false,
      isSynced: json['is_synced'] is int 
          ? json['is_synced'] == 1 
          : true,
      version: json['version'] ?? 1,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'category_id': categoryId,
      'priority': priority,
      'tags': tags,
      'due_date': dueDate?.toIso8601String(),
      'reminder_time': reminderTime?.toIso8601String(),
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'is_synced': isSynced,
      'version': version,
    };
  }
  
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'client_id': clientId,
      'title': title,
      'description': description,
      'is_completed': isCompleted ? 1 : 0,
      'category_id': categoryId,
      'priority': priority,
      'tags': tags.join(','),
      'due_date': dueDate?.toIso8601String(),
      'reminder_time': reminderTime?.toIso8601String(),
      'position': position,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'version': version,
    };
  }
  
  Todo copyWith({
    int? id,
    String? clientId,
    String? title,
    String? description,
    bool? isCompleted,
    int? categoryId,
    String? priority,
    List<String>? tags,
    DateTime? dueDate,
    DateTime? reminderTime,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isSynced,
    int? version,
  }) {
    return Todo(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      version: version ?? this.version,
    );
  }
  
  @override
  List<Object?> get props => [
        id,
        clientId,
        title,
        description,
        isCompleted,
        categoryId,
        priority,
        tags,
        dueDate,
        reminderTime,
        position,
        createdAt,
        updatedAt,
        isDeleted,
        isSynced,
        version,
      ];
}
