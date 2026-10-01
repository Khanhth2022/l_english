import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/app_config.dart';

/// Gắn JWT vào mọi request và tự làm mới token khi gặp 401.
///
/// Luồng của backend: access token ngắn hạn (15–60 phút) + refresh token dài hạn.
/// Khi access token hết hạn, interceptor sẽ:
/// 1. gọi `POST /api/auth/refresh` bằng refresh token;
/// 2. lưu cặp token mới (backend xoay vòng refresh token);
/// 3. gọi lại request vừa hỏng **đúng một lần**.
///
/// Nhiều request cùng hỏng 401 một lúc sẽ dùng chung một lần refresh
/// ([_refreshing]). Nếu mỗi request tự refresh thì việc xoay vòng refresh token
/// sẽ vô hiệu hoá lẫn nhau và người dùng bị đăng xuất oan.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.client,
    required this.refreshClient,
    required this.tokenStore,
    this.refreshPath = AppConfig.refreshPath,
  });

  final Dio client;
  final Dio refreshClient;
  final TokenStore tokenStore;
  final String refreshPath;

  static const String _retriedFlag = 'authRetried';
  static const String _skipAuthFlag = 'skipAuth';

  Future<String?>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenStore.tokens?.accessToken;
    if (token != null &&
        token.isNotEmpty &&
        options.extra[_skipAuthFlag] != true) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    unawaited(_handleError(err, handler));
  }

  Future<void> _handleError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final options = err.requestOptions;
      final isUnauthorized = err.response?.statusCode == 401;
      final isRefreshItself = options.path.contains(refreshPath);
      final alreadyRetried = options.extra[_retriedFlag] == true;

      if (!isUnauthorized || isRefreshItself || alreadyRetried) {
        handler.next(err);
        return;
      }

      final accessToken = await _refreshToken();
      if (accessToken == null) {
        // Refresh token cũng hết hiệu lực → để lỗi 401 nổi lên cho giao diện
        // yêu cầu đăng nhập lại.
        handler.next(err);
        return;
      }

      options.extra[_retriedFlag] = true;
      options.headers['Authorization'] = 'Bearer $accessToken';
      final response = await client.fetch<Object?>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _refreshToken() {
    return _refreshing ??= _performRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = tokenStore.tokens?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await refreshClient.post<Object?>(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data is! Map) return null;

      final newAccess = data['accessToken'] ?? data['access_token'];
      final newRefresh = data['refreshToken'] ?? data['refresh_token'];
      if (newAccess is! String || newAccess.isEmpty) return null;

      await tokenStore.save(
        TokenPair(
          accessToken: newAccess,
          refreshToken: newRefresh is String && newRefresh.isNotEmpty
              ? newRefresh
              : refreshToken,
        ),
      );
      return newAccess;
    } catch (_) {
      // Refresh token hết hạn hoặc đã bị thu hồi → xoá phiên hiện tại.
      await tokenStore.clear();
      return null;
    }
  }
}
