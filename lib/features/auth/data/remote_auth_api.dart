import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'auth_api.dart';
import 'models/auth_models.dart';

/// Gọi trực tiếp API xác thực của Spring Boot backend.
class RemoteAuthApi implements AuthApi {
  RemoteAuthApi(this._dio);

  final Dio _dio;

  @override
  Future<AuthResponse> login(String username, String password) => _call(() async {
    final response = await _dio.post<Object?>(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );
    final data = response.data;
    if (data is Map) {
      return AuthResponse.fromJson(Map<String, dynamic>.from(data));
    }
    throw ApiException(0, 'Máy chủ không trả về thông tin token.');
  });

  @override
  Future<String> register(String username, String password) => _call(() async {
    final response = await _dio.post<Object?>(
      '/api/auth/register',
      data: {'username': username, 'password': password},
    );
    final data = response.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Đăng ký tài khoản thành công.';
  });

  @override
  Future<void> logout(String refreshToken) => _call(() async {
    await _dio.post<Object?>(
      '/api/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  });

  @override
  Future<AuthResponse> refresh(String refreshToken) => _call(() async {
    final response = await _dio.post<Object?>(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data;
    if (data is Map) {
      return AuthResponse.fromJson(Map<String, dynamic>.from(data));
    }
    throw ApiException(0, 'Máy chủ không trả về token mới.');
  });

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapDioException(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(0, 'Không xử lý được dữ liệu ($error).');
    }
  }
}
