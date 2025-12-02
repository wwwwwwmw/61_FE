class AppConstants {
  // ⚠️ QUAN TRỌNG:
  // - Nếu chạy máy ảo Android (Emulator): Dùng '10.0.2.2'
  // - Nếu chạy máy ảo iOS: Dùng 'localhost' hoặc '127.0.0.1'
  // - Nếu chạy thiết bị thật (điện thoại): Dùng IP LAN của máy tính (VD: '192.168.1.x')
  static const String baseUrl = 'http://172.20.10.3:3000';

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
  static const String monthlyBudgetKey = 'monthly_budget';

  // [CÁC KEY BỊ THIẾU GÂY LỖI]
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String userNameKey = 'user_name';
  static const String languageKey = 'language';

  // Database Conf
  static const String databaseName = 'personal_utility.db';
  static const int databaseVersion = 1;

  // Timeouts & Intervals
  static const Duration syncInterval = Duration(minutes: 5);
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Notification Channels
  static const String todoChannelId = 'todo_notifications';
  static const String budgetChannelId = 'budget_notifications';
  static const String eventChannelId = 'event_notifications';
}
