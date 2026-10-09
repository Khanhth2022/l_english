import 'models/auth_models.dart';

/// Hợp đồng API cho phân hệ Quản lý tài khoản (Auth) theo tài liệu thiết kế:
///
/// | Chức năng     | Endpoint               |
/// |--------------|------------------------|
/// | Đăng ký       | `POST /api/auth/register` |
/// | Đăng nhập     | `POST /api/auth/login`    |
/// | Đăng xuất     | `POST /api/auth/logout`   |
/// | Làm mới token | `POST /api/auth/refresh`  |
abstract class AuthApi {
  Future<AuthResponse> login(String username, String password);

  Future<String> register(String username, String password);

  Future<void> logout(String refreshToken);

  Future<AuthResponse> refresh(String refreshToken);
}
