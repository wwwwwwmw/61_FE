import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/services/event_service.dart';
import '../../features/events/domain/entities/event.dart';

class EventFormScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final Event? event;

  const EventFormScreen({
    super.key,
    required this.prefs,
    this.event,
  });

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _eventDate = DateTime.now();
  TimeOfDay _eventTime = TimeOfDay.now();
  String _themeColor = '#FF5722'; // Default orange
  bool _isAnnual = false;
  bool _isLoading = false;

  late final EventService _eventService;

  final List<Color> _colors = [
    const Color(0xFFFF5722), // Deep Orange
    const Color(0xFFE91E63), // Pink
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFFC107), // Amber
    const Color(0xFF795548), // Brown
    const Color(0xFF607D8B), // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _eventService = EventService(ApiClient(widget.prefs));

    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description ?? '';
      _eventDate = widget.event!.eventDate;
      _eventTime = TimeOfDay.fromDateTime(widget.event!.eventDate);
      _themeColor = widget.event!.themeColor;
      _isAnnual = widget.event!.isAnnual;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date != null) {
      setState(() => _eventDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _eventTime,
    );

    if (time != null) {
      setState(() => _eventTime = time);
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFFF5722);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dateTime = DateTime(
        _eventDate.year,
        _eventDate.month,
        _eventDate.day,
        _eventTime.hour,
        _eventTime.minute,
      );

      final eventData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'event_date': dateTime.toIso8601String(),
        'color': _themeColor,
        'is_recurring': _isAnnual,
        'notification_enabled': true,
      };

      if (widget.event == null) {
        await _eventService.createEvent(eventData);
      } else {
        await _eventService.updateEvent(widget.event!.id.toString(), eventData);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.event == null
                ? 'Đã thêm sự kiện'
                : 'Đã cập nhật sự kiện'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Thêm Sự Kiện' : 'Sửa Sự Kiện'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveEvent,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề *',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tiêu đề';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ngày',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_eventDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Giờ',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_eventTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Color Picker
            const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((color) {
                final isSelected = _themeColor == _colorToHex(color);
                return GestureDetector(
                  onTap: () => setState(() => _themeColor = _colorToHex(color)),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Recurring Switch
            SwitchListTile(
              title: const Text('Sự kiện hàng năm'),
              subtitle: const Text('Lặp lại vào ngày này mỗi năm'),
              value: _isAnnual,
              onChanged: (value) => setState(() => _isAnnual = value),
              secondary: const Icon(Icons.loop),
            ),
          ],
        ),
      ),
    );
  }
}
