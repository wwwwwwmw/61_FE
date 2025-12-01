import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  late final Dio _dio;
  final SharedPreferences _prefs;

  ApiClient(this._prefs) {
    final customBaseUrl = _prefs.getString('api_base_url');
    _dio = Dio(
      BaseOptions(
        baseUrl: customBaseUrl ?? AppConstants.baseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to requests
          final token = _prefs.getString(AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors and refresh token
          if (error.response?.statusCode == 401) {
            try {
              await _refreshToken();
              // Retry the request
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              // Refresh failed, logout user
              await _prefs.clear();
              return handler.reject(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> _refreshToken() async {
    final refreshToken = _prefs.getString(AppConstants.refreshTokenKey);
    if (refreshToken == null) throw Exception('No refresh token');

    final response = await _dio.post(
      '${AppConstants.authEndpoint}/refresh',
      data: {'refreshToken': refreshToken},
    );

    if (response.data['success']) {
      await _prefs.setString(
        AppConstants.accessTokenKey,
        response.data['data']['accessToken'],
      );
    }
  }

  // Generic GET request
  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  // Generic POST request
  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  // Generic PUT request
  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  // Generic PATCH request
  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  // Generic DELETE request
  Future<Response> delete(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return await _dio.delete(path, queryParameters: queryParameters);
  }
}
