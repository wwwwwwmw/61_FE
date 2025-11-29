class AppConstants {
  // ⚠️ QUAN TRỌNG: 
  // - Nếu chạy máy ảo Android (Emulator): Dùng '10.0.2.2'
  // - Nếu chạy máy ảo iOS: Dùng 'localhost' hoặc '127.0.0.1'
  // - Nếu chạy thiết bị thật (điện thoại): Dùng IP LAN của máy tính (VD: '192.168.1.x')
  // Hãy thay đổi dòng dưới đây cho phù hợp:
  static const String baseUrl = 'http://192.168.101.166:3000'; 

  static const String apiPrefix = '/api';

  // Endpoints
  static const String authEndpoint = '$apiPrefix/auth';
  static const String todosEndpoint = '$apiPrefix/todos';
  static const String expensesEndpoint = '$apiPrefix/expenses';
  static const String eventsEndpoint = '$apiPrefix/events';
  static const String categoriesEndpoint = '$apiPrefix/categories';
  static const String budgetsEndpoint = '$apiPrefix/budgets';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String lastSyncKey = 'last_sync_time';
  static const String themeKey = 'theme_mode';

  // Database Conf
  static const String databaseName = 'personal_utility.db';
  static const int databaseVersion = 1;
  static const Duration syncInterval = Duration(minutes: 5);
}