import '../../../../core/network/api_exception.dart';

/// Hồ sơ người dùng trả bởi `GET/PUT /api/users/me`.
///
/// `username` là khoá đăng nhập và không đổi; `name` là tên hiển thị do người
/// dùng tự đặt (được phép trùng, có thể chưa có).
class UserProfile {
  const UserProfile({required this.id, required this.username, this.name});

  final int id;
  final String username;

  /// Tên hiển thị; `null` khi tài khoản chưa đặt tên.
  final String? name;

  /// Tên để hiển thị: ưu tiên tên tự đặt, chưa có thì dùng username.
  String get displayName => name ?? username;

  bool get hasCustomName => name != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    if (id is! int || username is! String || username.trim().isEmpty) {
      throw ApiException(0, 'Máy chủ trả về hồ sơ người dùng không hợp lệ.');
    }

    final rawName = json['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;

    return UserProfile(id: id, username: username.trim(), name: name);
  }

  UserProfile copyWith({String? name}) =>
      UserProfile(id: id, username: username, name: name ?? this.name);
}
