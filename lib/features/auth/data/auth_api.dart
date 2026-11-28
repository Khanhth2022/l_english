import 'models/auth_models.dart';

/// Hợp đồng API cho phân hệ Quản lý tài khoản (Auth) theo tài liệu thiết kế:
///
/// | Chức năng     | Endpoint                         |
/// |---------------|----------------------------------|
/// | Đăng ký bước 1 | `POST /api/auth/register`       |
/// | Đăng ký bước 2 | `POST /api/auth/register/confirm` |
/// | Đăng nhập     | `POST /api/auth/login`           |
/// | Đăng xuất     | `POST /api/auth/logout`          |
/// | Làm mới token | `POST /api/auth/refresh`         |
/// | Đổi mật khẩu  | `POST /api/auth/change-password` |
/// | Quên mật khẩu | `POST /api/auth/forgot-password` |
/// | Đặt lại mật khẩu | `POST /api/auth/reset-password` |
abstract class AuthApi {
  Future<AuthResponse> login(String username, String password);

  /// §5.1 — đăng ký bước 1: yêu cầu mã xác thực qua email.
  ///
  /// Endpoint KHÔNG tạo tài khoản và không cấp token: backend chỉ ghi bản nháp
  /// `pending_registrations` (mật khẩu BCrypt, mã SHA-256) rồi gửi mã 6 số
  /// sống 10 phút. Dòng `users` chỉ xuất hiện sau [confirmRegistration].
  ///
  /// Gọi lại chính hàm này là "gửi lại mã": mỗi lần phát mã mới và mã cũ bị
  /// huỷ ngay, không có cooldown. `email` là kênh khôi phục duy nhất của tài
  /// khoản, còn `username` mới là khoá đăng nhập.
  Future<String> register({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  /// §5.1 — đăng ký bước 2: xác thực mã 6 số đã nhận qua email.
  ///
  /// Thành công tạo tài khoản (201) và xoá bản nháp trong cùng transaction,
  /// nhưng KHÔNG cấp token: người dùng quay về màn Đăng nhập và đăng nhập
  /// bằng `username`. Mã sai/hết hạn/không có bản nháp đều trả cùng một câu
  /// 400; sai 5 lần thì bản nháp bị huỷ, phải đăng ký lại từ bước 1.
  Future<String> confirmRegistration(String email, String code);

  Future<void> logout(String refreshToken);

  Future<AuthResponse> refresh(String refreshToken);

  /// §2.5 — đổi mật khẩu của chính tài khoản đang đăng nhập.
  ///
  /// Backend lấy tài khoản từ Bearer token nên hợp đồng không có tham số
  /// username: không thể đổi mật khẩu của người khác. Thành công trả về thông
  /// báo của máy chủ và thu hồi mọi refresh token của tài khoản.
  Future<String> changePassword(String currentPassword, String newPassword);

  /// §2.6 — quên mật khẩu, bước 1: yêu cầu mã xác thực gửi tới email.
  ///
  /// Tài khoản được tra theo email (không phải username). Backend luôn trả
  /// 200 với đúng một câu thông báo dù email có đăng ký hay không, và cả khi
  /// SMTP lỗi — để không ai dò được email nào có tài khoản.
  Future<String> forgotPassword(String email);

  /// §2.6 — quên mật khẩu, bước 2: đặt lại mật khẩu bằng mã 6 số đã nhận.
  ///
  /// Thành công KHÔNG cấp token: backend đổi hash, thu hồi toàn bộ refresh
  /// token và xoá mã đã dùng trong cùng transaction, nên người dùng phải đăng
  /// nhập lại bằng mật khẩu mới.
  Future<String> resetPassword(String email, String code, String newPassword);
}
