import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/services/event_service.dart';
import '../../features/events/domain/entities/event.dart';
import 'event_form_screen.dart';

class EventListScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const EventListScreen({super.key, required this.prefs});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  late final EventService _eventService;
  // Store raw rows to retain client_id for offline-first operations
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  Timer? _timer;
  // Filters
  List<Map<String, dynamic>> _categories = [];
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _eventService = EventService(ApiClient(widget.prefs));
    _fetchInitial();

    // Timer to update countdown every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitial() async {
    await Future.wait([
      _fetchCategories(),
      _fetchEvents(),
    ]);
  }

  Future<void> _fetchCategories() async {
    try {
      final api = ApiClient(widget.prefs);
      final res = await api.get('/categories');
      final data = res.data;
      if (data is List) {
        setState(() => _categories = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      // silent fail, giữ UI hoạt động
    }
  }

  Future<void> _fetchEvents() async {
    try {
      final eventsData = await _eventService.getEvents();
      if (mounted) {
        setState(() {
          _events = List<Map<String, dynamic>>.from(eventsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Don't show mock data on error, just show empty or error message
        print("Error fetching events: $e");
      }
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> eventRow) async {
    final displayTitle = (eventRow['title'] as String?) ?? 'sự kiện';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: Text('Bạn có chắc muốn xóa "$displayTitle" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    final clientId = eventRow['client_id']?.toString();
    if (confirm == true && clientId != null && clientId.isNotEmpty) {
      try {
        await _eventService.deleteEvent(clientId);
        _fetchEvents(); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa sự kiện')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa: $e')),
          );
        }
      }
    }
  }

  void _navigateToForm({Map<String, dynamic>? eventRow}) async {
    final Event? event = eventRow != null ? Event.fromJson(eventRow) : null;
    final String? clientId =
        eventRow != null ? eventRow['client_id']?.toString() : null;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          prefs: widget.prefs,
          event: event,
          clientId: clientId,
        ),
      ),
    );

    if (result == true) {
      _fetchEvents();
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.blue;
    try {
      hexColor = hexColor.replaceAll("#", "");
      if (hexColor.length == 6) {
        return Color(int.parse("0xFF$hexColor"));
      }
    } catch (_) {}
    return Colors.blue;
  }

  List<Map<String, dynamic>> get _filteredEvents {
    return _events.where((row) {
      final String? dateStr = row['event_date'] as String?;
      if (dateStr == null) return false;
      final DateTime eventDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      // Hiện tại schema events không có category_id, nên chỉ áp dụng lọc theo ngày.
      if (_dateRange != null) {
        if (eventDate.isBefore(_dateRange!.start) ||
            eventDate.isAfter(_dateRange!.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 7))),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // Category chips
          // Danh mục: Hiển thị nhưng không gắn với sự kiện (placeholder nếu sau này bổ sung schema)
          ..._categories.map((c) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(c['name'] ?? 'Danh mục'),
              ),
            );
          }),
          // Date Range
          ChoiceChip(
            label: Text(_dateRange == null
                ? 'Khoảng thời gian'
                : '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}'),
            selected: _dateRange != null,
            onSelected: (_) => _pickDateRange(),
          ),
          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                label: const Text('Xóa lọc'),
                onPressed: () => setState(() => _dateRange = null),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đếm Ngược Sự Kiện"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text("Chưa có sự kiện nào"))
              : Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchEvents,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredEvents.length,
                          itemBuilder: (context, index) {
                            final eventRow = _filteredEvents[index];
                            return _buildEventCard(eventRow);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> eventRow) {
    final event = Event.fromJson(eventRow);
    final now = DateTime.now();
    // Với sự kiện đếm ngược có lặp lại, tính mốc tiếp theo
    final target = (event.eventType == 'countdown' &&
            (event.isAnnual || (event.recurrencePattern != null)))
        ? event.nextOccurrenceAfter(now)
        : event.eventDate;
    Duration difference = target.difference(now);
    bool isPast = difference.isNegative;

    final days = difference.inDays.abs();
    final hours = (difference.inHours % 24).abs();
    final minutes = (difference.inMinutes % 60).abs();
    final seconds = (difference.inSeconds % 60).abs();

    final color = _parseColor(event.themeColor);

    return GestureDetector(
      onTap: () => _navigateToForm(eventRow: eventRow),
      onLongPress: () => _deleteEvent(eventRow),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Delete option (optional visual cue)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (event.isAnnual)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.loop, color: Colors.white70),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        onPressed: () => _deleteEvent(eventRow),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(target),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),

              // Countdown
              isPast
                  ? const Center(
                      child: Text(
                        "Đã diễn ra",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeBlock(days, "Ngày"),
                        _buildColon(),
                        _buildTimeBlock(hours, "Giờ"),
                        _buildColon(),
                        _buildTimeBlock(minutes, "Phút"),
                        _buildColon(),
                        _buildTimeBlock(seconds, "Giây"),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColon() {
    return const Text(
      ":",
      style: TextStyle(
        color: Colors.white54,
        fontSize: 30,
        fontWeight: FontWeight.bold,
        height: 0.8,
      ),
    );
  }

  Widget _buildTimeBlock(int value, String label) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }
}
