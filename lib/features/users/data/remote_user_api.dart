import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'models/user_profile.dart';
import 'user_api.dart';

/// Gọi thật hai endpoint hồ sơ người dùng của Spring Boot backend.
class RemoteUserApi implements UserApi {
  RemoteUserApi(this._dio);

  final Dio _dio;

  @override
  Future<UserProfile> fetchProfile() => _call(() async {
    final response = await _dio.get<Object?>('/api/users/me');
    // GET trả trần UserProfileDto, không bọc trong `data`.
    return _profileFrom(response.data, wrapped: false);
  });

  @override
  Future<UserProfile> updateName(String name) => _call(() async {
    final response = await _dio.put<Object?>(
      '/api/users/me',
      data: {'name': name.trim()},
    );
    // PUT bọc trong SuccessResponse: `{ "message": ..., "data": {...} }`.
    return _profileFrom(response.data, wrapped: true);
  });

  UserProfile _profileFrom(Object? body, {required bool wrapped}) {
    final data = wrapped && body is Map ? body['data'] : body;
    if (data is Map) {
      return UserProfile.fromJson(Map<String, dynamic>.from(data));
    }
    throw ApiException(0, 'Máy chủ không trả về hồ sơ người dùng.');
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapDioException(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      debugPrint('RemoteUserApi: phản hồi không hợp lệ ($error).');
      throw ApiException(0, 'Máy chủ trả về dữ liệu không hợp lệ.');
    }
  }
}
