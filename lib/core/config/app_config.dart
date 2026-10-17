import 'package:dio/dio.dart';

import '../network/auth_interceptor.dart';
import '../network/ssl_helper.dart';

/// Cấu hình lúc chạy, đọc từ biến biên dịch (`--dart-define`) để đổi môi trường
/// mà không phải sửa code, hỗ trợ chỉnh động trong ứng dụng.
class AppConfig {
  AppConfig._();

  /// Địa chỉ backend Spring Boot mặc định biên dịch.
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://stewart-resource-busy-bristol.trycloudflare.com',
  );

  /// Địa chỉ backend Spring Boot đang được sử dụng trong phiên làm việc.
  static String apiBaseUrl = defaultApiBaseUrl;

  /// Chuẩn hoá địa chỉ Base URL thông minh:
  /// - Tự động bổ sung giao thức (http:// cho localhost/IP, https:// cho domain).
  /// - Loại bỏ dấu gạch chéo cuối trang (`/`).
  /// - Loại bỏ hậu tố `/api` nếu người dùng lỡ dán kèm.
  static String normalizeUrl(String raw) {
    var formatted = raw.trim();
    if (formatted.isEmpty) return formatted;

    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      if (formatted.startsWith('localhost') ||
          formatted.startsWith('127.0.0.1') ||
          formatted.startsWith('10.0.2.2') ||
          RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(formatted)) {
        formatted = 'http://$formatted';
      } else {
        formatted = 'https://$formatted';
      }
    }

    while (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }

    if (formatted.endsWith('/api')) {
      formatted = formatted.substring(0, formatted.length - 4);
    }

    while (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }

    return formatted;
  }

  /// Cập nhật Base URL trong runtime và đồng bộ vào Dio client.
  static void setApiBaseUrl(String newUrl, [Dio? dio]) {
    final formatted = normalizeUrl(newUrl);
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

  /// Kiểm tra trực tiếp khả năng kết nối tới máy chủ backend.
  /// Bất kỳ phản hồi HTTP nào (kể cả 401, 400, 200) đều chứng minh máy chủ đang hoạt động.
  static Future<ConnectionTestResult> testConnection(
    String url, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty ||
        (!normalized.startsWith('http://') && !normalized.startsWith('https://'))) {
      return const ConnectionTestResult(
        isSuccess: false,
        message: 'Định dạng URL không hợp lệ.',
      );
    }

    final testDio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        validateStatus: (status) => true,
      ),
    );
    configureBypassCertificate(testDio);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await testDio.post<Object?>(
        '/api/auth/login',
        data: const <String, dynamic>{},
      );
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;
      return ConnectionTestResult(
        isSuccess: true,
        latencyMs: latency,
        statusCode: response.statusCode,
        message: 'Kết nối thành công (${latency}ms) - Máy chủ Spring Boot phản hồi tốt!',
      );
    } on DioException catch (e) {
      stopwatch.stop();
      if (e.response != null) {
        // Có phản hồi từ server nhưng mã lỗi
        final latency = stopwatch.elapsedMilliseconds;
        return ConnectionTestResult(
          isSuccess: true,
          latencyMs: latency,
          statusCode: e.response?.statusCode,
          message: 'Kết nối thành công (${latency}ms) - Máy chủ phản hồi (${e.response?.statusCode}).',
        );
      }

      String message;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Hết thời gian chờ kết nối (${timeout.inSeconds}s). Máy chủ phản hồi quá chậm.';
          break;
        case DioExceptionType.connectionError:
          final rawErr = e.error?.toString() ?? e.message ?? '';
          if (rawErr.contains('XMLHttpRequest') || rawErr.contains('CORS')) {
            message = 'Lỗi CORS trên Trình duyệt: Máy chủ backend chưa bật CORS cho web. Hãy test trên Android hoặc bật CORS ở backend.';
          } else if (rawErr.contains('Failed host lookup') || rawErr.contains('No address associated')) {
            message = 'Lỗi DNS: Thiết bị không tìm thấy tên miền này. Mạng WiFi/4G có thể đang chặn Cloudflare tunnel (thử bật 1.1.1.1 hoặc đổi DNS sang 8.8.8.8).';
          } else if (rawErr.contains('Connection refused')) {
            message = 'Từ chối kết nối (Connection Refused): Cổng máy chủ chưa mở hoặc sai IP/cổng.';
          } else {
            message = 'Không thể kết nối tới máy chủ ($rawErr). Vui lòng kiểm tra lại URL hoặc mạng WiFi/4G.';
          }
          break;
        case DioExceptionType.badCertificate:
          message = 'Lỗi chứng chỉ bảo mật SSL/HTTPS của máy chủ.';
          break;
        default:
          message = 'Lỗi kết nối: ${e.message ?? 'Không xác định'}';
      }
      return ConnectionTestResult(
        isSuccess: false,
        message: message,
      );
    } catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        isSuccess: false,
        message: 'Lỗi không xác định ($e).',
      );
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

/// Kết quả kiểm tra kết nối tới máy chủ backend.
class ConnectionTestResult {
  const ConnectionTestResult({
    required this.isSuccess,
    required this.message,
    this.latencyMs,
    this.statusCode,
  });

  final bool isSuccess;
  final String message;
  final int? latencyMs;
  final int? statusCode;
}
