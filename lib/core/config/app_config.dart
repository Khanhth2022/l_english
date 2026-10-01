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
  /// - Android emulator: giữ mặc định `http://10.0.2.2:8080`
  ///   (trong emulator, `10.0.2.2` chính là `localhost` của máy tính).
  /// - Điện thoại thật: dùng IP LAN của máy tính, ví dụ `http://192.168.1.10:8080`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Bật API giả để app vẫn chạy được khi backend Java chưa xong.
  /// Tắt bằng `--dart-define=USE_MOCK_API=false`.
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );

  /// Đường dẫn làm mới token (nhánh `feature/auth`).
  static const String refreshPath = '/api/auth/refresh';

  static const Duration connectTimeout = Duration(seconds: 10);

  /// Rộng rãi hơn vì API sinh nghĩa từ có gọi dịch vụ AI bên ngoài.
  static const Duration receiveTimeout = Duration(seconds: 30);
}
