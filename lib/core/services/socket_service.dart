import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart'; // Import service mới tạo

typedef ReminderCallback = void Function(Map<String, dynamic> data);

class SocketService with ChangeNotifier {
  io.Socket? _socket;
  bool _connected = false;
  bool get isConnected => _connected;

  // Singleton
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  void connect() {
    if (_socket != null && _socket!.connected) return;

    final url = AppConstants.baseUrl;
    _socket = io.io(url, {
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
    });

    _socket!.on('connect', (_) {
      print('✅ Socket Connected');
      _connected = true;
      notifyListeners();
    });

    _socket!.on('disconnect', (_) {
      print('❌ Socket Disconnected');
      _connected = false;
      notifyListeners();
    });

    // --- LẮNG NGHE SỰ KIỆN NHẮC NHỞ TỪ SERVER ---
    _socket!.on('todo_reminder', (data) {
      print("📩 Nhận nhắc nhở: $data");
      if (data is Map) {
        // Hiển thị thông báo Local
        NotificationService().showNotification(
          id: data['id'] ?? 0,
          title: "⏰ Nhắc nhở công việc",
          body: data['title'] ?? "Bạn có công việc sắp đến hạn!",
        );
      }
    });
    // Thêm đoạn này vào dưới phần todo_reminder
    _socket!.on('event_due', (data) {
      print("🎉 Nhận sự kiện: $data");
      if (data is Map) {
        NotificationService().showNotification(
          id: (data['id'] ?? 0) + 1000, // ID khác todo để không bị đè
          title: "🎉 Sự kiện diễn ra",
          body: data['message'] ?? "Sự kiện ${data['title']} đang diễn ra!",
        );
      }
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connected = false;
    notifyListeners();
  }
}