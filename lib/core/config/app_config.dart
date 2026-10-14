/// Cấu hình lúc chạy, đọc từ biến biên dịch (`--dart-define`) để đổi môi trường
/// mà không phải sửa code.
///
/// Ví dụ chạy với backend thật trên máy trong cùng wifi:
/// ```
/// flutter run --dart-define=USE_MOCK_API=false \
///             --dart-define=API_BASE_URL=http://192.168.1.10:8080
/// ```
class AppConfig {
  const AppConfig._();

  /// Địa chỉ backend Spring Boot.
  ///
  /// Mặc định trỏ đến Cloudflare tunnel backend hoặc có thể ghi đè qua `--dart-define=API_BASE_URL=...`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://lightweight-drawn-delayed-loves.trycloudflare.com',
  );

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
