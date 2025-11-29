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
  List<Event> _events = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _eventService = EventService(ApiClient(widget.prefs));
    _fetchEvents();

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

  Future<void> _fetchEvents() async {
    try {
      final eventsData = await _eventService.getEvents();
      if (mounted) {
        setState(() {
          _events = eventsData.map((e) => Event.fromJson(e)).toList();
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

  Future<void> _deleteEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: Text('Bạn có chắc muốn xóa "${event.title}" không?'),
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

    if (confirm == true && event.id != null) {
      try {
        await _eventService.deleteEvent(event.id.toString());
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

  void _navigateToForm([Event? event]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          prefs: widget.prefs,
          event: event,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đếm Ngược Sự Kiện"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text("Chưa có sự kiện nào"))
              : RefreshIndicator(
                  onRefresh: _fetchEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _buildEventCard(event);
                    },
                  ),
                ),
    );
  }

  Widget _buildEventCard(Event event) {
    final now = DateTime.now();
    Duration difference = event.eventDate.difference(now);
    bool isPast = difference.isNegative;

    final days = difference.inDays.abs();
    final hours = (difference.inHours % 24).abs();
    final minutes = (difference.inMinutes % 60).abs();
    final seconds = (difference.inSeconds % 60).abs();

    final color = _parseColor(event.themeColor);

    return GestureDetector(
      onTap: () => _navigateToForm(event),
      onLongPress: () => _deleteEvent(event),
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
                  if (event.isAnnual)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.loop, color: Colors.white70),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(event.eventDate),
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
