import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class AuthService {
  final Dio _dio;
  final SharedPreferences _prefs;

  AuthService(this._prefs)
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.baseUrl,
          connectTimeout: AppConstants.connectionTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

  // Send OTP (registration or forgot_password)
  Future<bool> sendOtp(String email, {String type = 'registration'}) async {
    try {
      final res = await _dio.post(
        '${AppConstants.authEndpoint}/send-otp',
        data: {'email': email, 'type': type},
      );
      return res.data['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Verify OTP
  Future<bool> verifyOtp(String email, String otp) async {
    try {
      final res = await _dio.post(
        '${AppConstants.authEndpoint}/verify-otp',
        data: {'email': email, 'otp': otp},
      );
      
      if (res.data['success'] == true) {
        // Backend returns tokens on successful verification
        if (res.data['data'] != null) {
          await _persistAuth(res.data['data']);
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Register new user (uses fullName to match backend, keep name alias for backwards compatibility)
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.authEndpoint}/register',
        data: {
          'email': email,
          'password': password,
          'fullName': fullName,
          'otp': otp,
        },
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Đăng ký thất bại');
      }
      final data = response.data['data'];
      await _persistAuth(data);
      return Map<String, dynamic>.from(data['user']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Legacy simple register (without OTP) retained for compatibility
  Future<Map<String, dynamic>> registerSimple({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.authEndpoint}/register',
        data: {
          'email': email,
          'password': password,
          'fullName': name,
          // OTP omitted; backend will reject if required.
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConstants.authEndpoint}/login',
        data: {'email': email, 'password': password},
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Đăng nhập thất bại');
      }
      final data = response.data['data'];
      await _persistAuth(data);
      return Map<String, dynamic>.from(data['user']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Refresh access token
  Future<String?> refreshAccessToken() async {
    final refreshToken = _prefs.getString(AppConstants.refreshTokenKey);
    if (refreshToken == null) return null;
    try {
      final res = await _dio.post(
        '${AppConstants.authEndpoint}/refresh',
        data: {'refreshToken': refreshToken},
      );
      if (res.data['success'] == true) {
        final token = res.data['data']['accessToken'];
        if (token != null) {
          await _prefs.setString(AppConstants.accessTokenKey, token);
        }
        return token;
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await _prefs.remove(AppConstants.accessTokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
    await _prefs.remove(AppConstants.userIdKey);
    await _prefs.remove(AppConstants.userEmailKey);
    await _prefs.remove(AppConstants.userNameKey);
  }

  Future<void> _persistAuth(dynamic data) async {
    if (data is Map<String, dynamic>) {
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];
      final user = data['user'] as Map<String, dynamic>;
      if (accessToken != null) {
        await _prefs.setString(AppConstants.accessTokenKey, accessToken);
      }
      if (refreshToken != null) {
        await _prefs.setString(AppConstants.refreshTokenKey, refreshToken);
      }
      if (user['id'] != null) {
        await _prefs.setString(AppConstants.userIdKey, user['id'].toString());
      }
      if (user['email'] != null) {
        await _prefs.setString(AppConstants.userEmailKey, user['email']);
      }
      final name = user['fullName'] ?? user['full_name'] ?? user['name'];
      if (name != null) {
        await _prefs.setString(AppConstants.userNameKey, name);
      }
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final message = e.response?.data['message'];
      return message ?? 'Lỗi kết nối server';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return 'Timeout - Kiểm tra kết nối mạng';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Server không phản hồi';
    } else {
      return 'Không kết nối được server: ${e.message}';
    }
  }
}
