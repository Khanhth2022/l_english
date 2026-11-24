import 'models/auth_models.dart';

/// Hợp đồng API cho phân hệ Quản lý tài khoản (Auth) theo tài liệu thiết kế:
///
/// | Chức năng     | Endpoint                         |
/// |---------------|----------------------------------|
/// | Đăng ký       | `POST /api/auth/register`        |
/// | Đăng nhập     | `POST /api/auth/login`           |
/// | Đăng xuất     | `POST /api/auth/logout`          |
/// | Làm mới token | `POST /api/auth/refresh`         |
/// | Đổi mật khẩu  | `POST /api/auth/change-password` |
abstract class AuthApi {
  Future<AuthResponse> login(String username, String password);

  /// §5.1 — tạo tài khoản mới.
  ///
  /// `name` là tên hiển thị bắt buộc (1–100 ký tự, được phép trùng): backend
  /// lưu vào cột `users.name` (migration `V3__add_user_name.sql`). `username`
  /// vẫn là khoá đăng nhập duy nhất.
  Future<String> register(
    String username,
    String password, {
    required String name,
  });

  Future<void> logout(String refreshToken);

  Future<AuthResponse> refresh(String refreshToken);

  /// §2.5 — đổi mật khẩu của chính tài khoản đang đăng nhập.
  ///
  /// Backend lấy tài khoản từ Bearer token nên hợp đồng không có tham số
  /// username: không thể đổi mật khẩu của người khác. Thành công trả về thông
  /// báo của máy chủ và thu hồi mọi refresh token của tài khoản.
  Future<String> changePassword(String currentPassword, String newPassword);
}
