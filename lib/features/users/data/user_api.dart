import 'models/user_profile.dart';

/// Hợp đồng API hồ sơ người dùng (`/api/users`):
///
/// | Chức năng        | Endpoint            |
/// |------------------|---------------------|
/// | Xem hồ sơ        | `GET /api/users/me`  |
/// | Đổi tên hiển thị | `PUT /api/users/me`  |
///
/// Tài khoản lấy từ Bearer token nên không có id trên URL: mỗi người chỉ đọc
/// và sửa được hồ sơ của chính mình.
abstract class UserApi {
  Future<UserProfile> fetchProfile();

  /// Đổi tên hiển thị. Backend trim hai đầu trước khi lưu và trả hồ sơ mới
  /// trong `data` của `SuccessResponse`.
  Future<UserProfile> updateName(String name);
}
