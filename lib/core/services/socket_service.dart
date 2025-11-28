import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

typedef ReminderCallback = void Function(Map<String, dynamic> data);

class SocketService with ChangeNotifier {
  io.Socket? _socket;
  bool _connected = false;
  bool get isConnected => _connected;

  ReminderCallback? onTodoReminder;
  ReminderCallback? onEventDue;

  void connect({String? token}) {
    if (_socket != null) return; // already connecting or connected
    final url = AppConstants.baseUrl; // base already includes protocol & host
    _socket = io.io(url, {
      'transports': ['websocket'],
      'autoConnect': true,
      'forceNew': true,
      'extraHeaders': token != null ? {'Authorization': 'Bearer $token'} : {},
    });

    _socket!.on('connect', (_) {
      _connected = true;
      notifyListeners();
    });

    _socket!.on('disconnect', (_) {
      _connected = false;
      notifyListeners();
    });

    _socket!.on('todo_reminder', (data) {
      if (data is Map) {
        onTodoReminder?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('event_due', (data) {
      if (data is Map) {
        onEventDue?.call(Map<String, dynamic>.from(data));
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
