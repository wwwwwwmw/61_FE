import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import chuẩn
import '../../core/network/api_client.dart';

// --- 1. MODEL CLASS ---
class EventModel {
  final int id;
  final String title;
  final DateTime eventDate;
  final String themeColor;
  final bool isAnnual;

  EventModel({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.themeColor,
    required this.isAnnual,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      title: json['title'],
      eventDate: DateTime.parse(json['event_date']),
      themeColor:
          json['color'] ??
          json['theme_color'] ??
          '#FF5722', // Support cả 2 key màu
      isAnnual:
          json['is_recurring'] == 1 ||
          json['is_annual'] == true, // Support cả 2 kiểu boolean
    );
  }
}

// --- 2. MAIN SCREEN ---
class EventListScreen extends StatefulWidget {
  final SharedPreferences prefs; // 1. Thêm biến để lưu prefs

  const EventListScreen({super.key, required this.prefs}); // 2. Sửa constructor

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  late final ApiClient _apiClient; // 3. Dùng late để khởi tạo sau
  List<EventModel> _events = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 4. Khởi tạo ApiClient với prefs được truyền từ widget cha
    _apiClient = ApiClient(widget.prefs);

    _fetchEvents();

    // Tạo bộ đếm cập nhật giao diện mỗi giây
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
      // Gọi API lấy danh sách sự kiện
      final response = await _apiClient.get('/events');
      if (response.statusCode == 200) {
        // Kiểm tra cấu trúc data trả về từ server
        final List<dynamic> data = response.data['data'] ?? [];

        if (mounted) {
          setState(() {
            _events = data.map((e) => EventModel.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Nếu lỗi, thêm dữ liệu giả để test giao diện
        _addMockData();
        print("Lỗi tải sự kiện (đã chuyển sang dữ liệu mẫu): $e");
      }
    }
  }

  void _addMockData() {
    _events = [
      EventModel(
        id: 1,
        title: "Tết Nguyên Đán 2026",
        eventDate: DateTime(2026, 2, 17),
        themeColor: "#D32F2F", // Đỏ
        isAnnual: true,
      ),
      EventModel(
        id: 2,
        title: "Sinh nhật Mẹ",
        eventDate: DateTime(2025, 12, 12),
        themeColor: "#7B1FA2", // Tím
        isAnnual: true,
      ),
      EventModel(
        id: 3,
        title: "Kỷ niệm ngày cưới",
        eventDate: DateTime(2026, 5, 28),
        themeColor: "#00796B", // Xanh ngọc
        isAnnual: true,
      ),
    ];
  }

  // Hàm chuyển đổi Hex String (#RRGGBB) sang Color
  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.blue;
    try {
      hexColor = hexColor.replaceAll("#", "");
      if (hexColor.length == 6) {
        return Color(int.parse("0xFF$hexColor"));
      }
    } catch (_) {}
    return Colors.blue; // Màu mặc định nếu lỗi
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Chức năng thêm sự kiện đang phát triển"),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(child: Text("Chưa có sự kiện nào"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return _buildEventCard(event);
              },
            ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    final now = DateTime.now();
    Duration difference = event.eventDate.difference(now);
    bool isPast = difference.isNegative;

    final days = difference.inDays.abs();
    final hours = (difference.inHours % 24).abs();
    final minutes = (difference.inMinutes % 60).abs();
    final seconds = (difference.inSeconds % 60).abs();

    final color = _parseColor(event.themeColor);

    return Container(
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
            // Tiêu đề
            Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(event.eventDate),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),

            // Bộ đếm
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
