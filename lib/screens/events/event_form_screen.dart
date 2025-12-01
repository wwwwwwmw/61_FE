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

class _EventFormScreenState extends State<EventFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _eventDate = DateTime.now();
  TimeOfDay _eventTime = TimeOfDay.now();
  String _themeColor = '#FF5722'; // Default orange
  bool _isRecurring = false;
  String? _recurrencePattern; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  bool _isLoading = false;
  late TabController _tabController;
  // Mode: 0 = Cố định (Fixed date/time), 1 = Đếm ngược (Countdown duration)
  int _modeIndex = 0;
  int _countdownHours = 0;
  int _countdownMinutes = 30; // default 30 minutes

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _modeIndex = _tabController.index);
    });

    if (widget.event != null) {
      // Khi sửa sự kiện hiện tại, luôn hiển thị ở chế độ "Cố định"
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description ?? '';
      _eventDate = widget.event!.eventDate;
      _eventTime = TimeOfDay.fromDateTime(widget.event!.eventDate);
      _themeColor = widget.event!.themeColor;
      _isRecurring = widget.event!.isAnnual; // backward-compatible mapping
      // If entity has recurrencePattern, map it; else default yearly when isAnnual
      _recurrencePattern = widget.event!.recurrencePattern ??
          (widget.event!.isAnnual ? 'yearly' : null);
      _modeIndex = 0;
      _tabController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
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

  // _hexToColor removed (unused)

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Tính toán event_date theo mode
      DateTime dateTime;
      if (_modeIndex == 0) {
        // Cố định
        dateTime = DateTime(
          _eventDate.year,
          _eventDate.month,
          _eventDate.day,
          _eventTime.hour,
          _eventTime.minute,
        );
      } else {
        // Đếm ngược
        final duration =
            Duration(hours: _countdownHours, minutes: _countdownMinutes);
        dateTime = DateTime.now().add(duration);
      }

      // Xây payload, bỏ các trường null để tránh 400 do validate
      final Map<String, dynamic> eventData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'event_date': dateTime.toIso8601String(),
        'color': _themeColor,
        'notification_enabled': true,
        'event_type': _modeIndex == 1 ? 'countdown' : 'fixed',
      };

      if (_modeIndex == 1) {
        eventData['countdown_hours'] = _countdownHours;
        eventData['countdown_minutes'] = _countdownMinutes;
      }
      if (_isRecurring && _recurrencePattern != null) {
        eventData['is_recurring'] = true;
        eventData['recurrence_pattern'] = _recurrencePattern;
      } else {
        eventData['is_recurring'] = false;
      }

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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cố định'),
            Tab(text: 'Đếm ngược'),
          ],
        ),
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
            // Mode specific input
            if (_modeIndex == 0) ...[
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
                        child:
                            Text(DateFormat('dd/MM/yyyy').format(_eventDate)),
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
            ] else ...[
              const Text('Thời lượng đếm ngược',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _countdownHours.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giờ',
                        prefixIcon: Icon(Icons.timer),
                      ),
                      onChanged: (v) {
                        final val = int.tryParse(v) ?? 0;
                        setState(() => _countdownHours = val.clamp(0, 999));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _countdownMinutes.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Phút',
                        prefixIcon: Icon(Icons.timelapse),
                      ),
                      onChanged: (v) {
                        final val = int.tryParse(v) ?? 0;
                        setState(() => _countdownMinutes = val.clamp(0, 59));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sẽ lưu thời điểm = Hiện tại + ${_countdownHours}h ${_countdownMinutes}m',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
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
            const Text('Màu sắc',
                style: TextStyle(fontWeight: FontWeight.bold)),
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

            // Recurrence controls (only in fixed mode)
            if (_modeIndex == 0) ...[
              SwitchListTile(
                title: const Text('Lặp lại'),
                subtitle: const Text('Tự động lặp theo chu kỳ đã chọn'),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value),
                secondary: const Icon(Icons.loop),
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Chu kỳ lặp',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _recurrencePattern,
                      hint: const Text('Chọn chu kỳ'),
                      items: const [
                        DropdownMenuItem(
                            value: 'daily', child: Text('Hàng ngày')),
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Hàng tuần')),
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Hàng tháng')),
                        DropdownMenuItem(
                            value: 'yearly', child: Text('Hàng năm')),
                      ],
                      onChanged: (v) => setState(() => _recurrencePattern = v),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
