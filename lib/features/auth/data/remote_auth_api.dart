import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'auth_api.dart';
import 'models/auth_models.dart';

/// Gọi trực tiếp API xác thực của Spring Boot backend.
class RemoteAuthApi implements AuthApi {
  RemoteAuthApi(this._dio);

  final Dio _dio;

  @override
  Future<AuthResponse> login(String username, String password) =>
      _call(() async {
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

  /// Bước 1 chỉ ghi bản nháp và gửi mã: backend trả 200 kèm `MessageResponse`,
  /// tuyệt đối không trả token. Gửi lại = gọi lại chính endpoint này.
  @override
  Future<String> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) => _call(() async {
    final response = await _dio.post<Object?>(
      '/api/auth/register',
      data: {
        'name': name.trim(),
        'username': username,
        'email': email.trim(),
        'password': password,
      },
    );
    return _messageOf(response.data, 'Mã xác thực đã được gửi tới email');
  });

  /// Bước 2: backend trả 201 nhưng vẫn không cấp token, nên người dùng phải
  /// đăng nhập lại bằng username sau khi xác thực xong.
  @override
  Future<String> confirmRegistration(String email, String code) =>
      _call(() async {
        final response = await _dio.post<Object?>(
          '/api/auth/register/confirm',
          data: {'email': email.trim(), 'code': code.trim()},
        );
        return _messageOf(response.data, 'Tạo tài khoản thành công');
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

  /// Tài khoản do Bearer token quyết định: body chỉ mang hai mật khẩu, đúng
  /// hợp đồng §2.5 của backend.
  @override
  Future<String> changePassword(String currentPassword, String newPassword) =>
      _call(() async {
        final response = await _dio.post<Object?>(
          '/api/auth/change-password',
          data: {
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          },
        );
        final data = response.data;
        if (data is Map && data['message'] is String) {
          return data['message'] as String;
        }
        return 'Đổi mật khẩu thành công';
      });

  /// Gửi đúng email người dùng nhập: backend tự chuẩn hoá (trim + chữ thường)
  /// trước khi tra `users.email`, nên client không cần tự đổi.
  @override
  Future<String> forgotPassword(String email) => _call(() async {
    final response = await _dio.post<Object?>(
      '/api/auth/forgot-password',
      data: {'email': email.trim()},
    );
    return _messageOf(
      response.data,
      'Nếu email này đã đăng ký, mã xác thực đã được gửi tới email đó',
    );
  });

  @override
  Future<String> resetPassword(String email, String code, String newPassword) =>
      _call(() async {
        final response = await _dio.post<Object?>(
          '/api/auth/reset-password',
          data: {
            'email': email.trim(),
            'code': code.trim(),
            'newPassword': newPassword,
          },
        );
        return _messageOf(response.data, 'Đặt lại mật khẩu thành công');
      });

  /// Backend bọc thành công trong `MessageResponse`; thiếu `message` thì dùng
  /// câu mặc định để UI không hiện chuỗi rỗng.
  String _messageOf(Object? data, String fallback) {
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    return fallback;
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapDioException(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      debugPrint('RemoteAuthApi: phản hồi không hợp lệ ($error).');
      throw ApiException(0, 'Máy chủ trả về dữ liệu không hợp lệ.');
    }
  }
}
