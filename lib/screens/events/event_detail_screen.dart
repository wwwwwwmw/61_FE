import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'dart:async';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onDelete;
  final Function(Map<String, dynamic>)? onUpdate;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.onDelete,
    this.onUpdate,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Timer? _timer;
  Duration? _timeRemaining;

  @override
  void initState() {
    super.initState();
    _calculateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateTimeRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTimeRemaining() {
    try {
      final eventDate = DateTime.parse(widget.event['event_date'].toString());
      final now = DateTime.now();

      if (eventDate.isAfter(now)) {
        setState(() {
          _timeRemaining = eventDate.difference(now);
        });
      } else {
        setState(() {
          _timeRemaining = null;
        });
      }
    } catch (e) {
      setState(() {
        _timeRemaining = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventType = widget.event['event_type'] ?? 'other';
    final eventDate = widget.event['event_date'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sự kiện'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // TODO: Navigate to event form screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Chức năng sửa đang được phát triển')),
              );
            },
          ),
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: const Text('Bạn có chắc muốn xóa sự kiện này?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.onDelete!();
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Close detail screen
                        },
                        child: const Text(
                          'Xóa',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.event['title'] ?? 'Không có tiêu đề',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Countdown Card (if upcoming)
            if (_timeRemaining != null) ...[
              Card(
                color: AppColors.primary.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Thời gian còn lại',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(_timeRemaining!),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Event Type
            _buildInfoRow(
              context,
              'Loại sự kiện',
              _getEventTypeText(eventType),
              icon: Icons.category,
            ),
            const Divider(height: 32),

            // Event Date
            _buildInfoRow(
              context,
              'Ngày sự kiện',
              _formatDateTime(eventDate),
              icon: Icons.calendar_today,
              color: _timeRemaining != null ? AppColors.primary : Colors.grey,
            ),
            const Divider(height: 32),

            // Description
            if (widget.event['description'] != null &&
                widget.event['description'].toString().isNotEmpty) ...[
              Text(
                'Mô tả',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.event['description'],
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Divider(height: 32),
            ],

            // Recurring
            if (widget.event['is_recurring'] == true) ...[
              Row(
                children: [
                  const Icon(Icons.repeat, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sự kiện lặp lại',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
              const Divider(height: 32),
            ],

            // Notification
            if (widget.event['notification_enabled'] == true) ...[
              Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Thông báo đã bật',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                  ),
                ],
              ),
              const Divider(height: 32),
            ],

            const SizedBox(height: 24),

            // Created/Updated info
            if (widget.event['created_at'] != null)
              Text(
                'Tạo lúc: ${_formatDateTime(widget.event['created_at'])}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            if (widget.event['updated_at'] != null)
              Text(
                'Cập nhật: ${_formatDateTime(widget.event['updated_at'])}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? color,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color ?? AppColors.primary, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }

  String _getEventTypeText(String type) {
    switch (type) {
      case 'birthday':
        return 'Sinh nhật';
      case 'meeting':
        return 'Cuộc họp';
      case 'deadline':
        return 'Hạn chót';
      case 'holiday':
        return 'Ngày lễ';
      default:
        return 'Khác';
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '$days ngày $hours giờ';
    } else if (hours > 0) {
      return '$hours giờ $minutes phút';
    } else if (minutes > 0) {
      return '$minutes phút $seconds giây';
    } else {
      return '$seconds giây';
    }
  }

  String _formatDateTime(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime =
          date is DateTime ? date : DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }
}
