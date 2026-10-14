import 'package:dio/dio.dart';

import '../network/auth_interceptor.dart';

/// Cấu hình lúc chạy, đọc từ biến biên dịch (`--dart-define`) để đổi môi trường
/// mà không phải sửa code, hỗ trợ chỉnh động trong ứng dụng.
class AppConfig {
  AppConfig._();

  /// Địa chỉ backend Spring Boot mặc định biên dịch.
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://lightweight-drawn-delayed-loves.trycloudflare.com',
  );

  /// Địa chỉ backend Spring Boot đang được sử dụng trong phiên làm việc.
  static String apiBaseUrl = defaultApiBaseUrl;

  /// Cập nhật Base URL trong runtime và đồng bộ vào Dio client.
  static void setApiBaseUrl(String newUrl, [Dio? dio]) {
    var formatted = newUrl.trim();
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    apiBaseUrl = formatted;
    if (dio != null) {
      dio.options.baseUrl = formatted;
      for (final interceptor in dio.interceptors) {
        if (interceptor is AuthInterceptor) {
          interceptor.refreshClient.options.baseUrl = formatted;
        }
      }
    }
  }

  /// Bật/tắt API giả lập.
  /// Mặc định dùng backend thật. Có thể bật lại bằng `--dart-define=USE_MOCK_API=true`.
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  /// Đường dẫn làm mới token (nhánh `feature/auth`).
  static const String refreshPath = '/api/auth/refresh';

  static const Duration connectTimeout = Duration(seconds: 10);

  /// Rộng rãi hơn vì API sinh nghĩa từ có gọi dịch vụ AI bên ngoài.
  static const Duration receiveTimeout = Duration(seconds: 30);
}
