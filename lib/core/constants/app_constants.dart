class AppConstants {
  // API Configuration - Use LAN IP for physical device (adjust IP to your PC's if different)
  // The backend listens on 0.0.0.0:3000; physical device must call the PC's IP.
  static const String baseUrl = 'http://172.20.10.3:3000';

  // API prefix
  static const String apiPrefix = '/api';

  // Endpoints with unified /api prefix (backend exposes /api/*)
  static const String authEndpoint = '$apiPrefix/auth';
  static const String todosEndpoint = '$apiPrefix/todos';
  static const String expensesEndpoint = '$apiPrefix/expenses';
  static const String eventsEndpoint = '$apiPrefix/events';
  static const String categoriesEndpoint = '$apiPrefix/categories';
  static const String budgetsEndpoint = '$apiPrefix/budgets';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String userNameKey = 'user_name';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String lastSyncKey = 'last_sync_time';

  // Database
  static const String databaseName = 'personal_utility.db';
  static const int databaseVersion = 1;

  // Pagination
  static const int itemsPerPage = 20;

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Sync Intervals
  static const Duration syncInterval = Duration(minutes: 5);

  // Notification Channels
  static const String todoChannelId = 'todo_notifications';
  static const String budgetChannelId = 'budget_notifications';
  static const String eventChannelId = 'event_notifications';
}
