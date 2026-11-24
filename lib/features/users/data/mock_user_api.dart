import '../../../core/network/api_exception.dart';
import 'models/user_profile.dart';
import 'user_api.dart';

/// Hồ sơ giả lập in-memory khi chạy mà không cần Spring Boot backend.
class MockUserApi implements UserApi {
  MockUserApi({
    this.latency = const Duration(milliseconds: 200),
    this.usernameProvider,
    this.nameProvider,
  });

  final Duration latency;

  /// Tên đăng nhập của phiên hiện tại — mock auth giữ phiên, còn mock users
  /// cần biết đang sửa hồ sơ của ai.
  final String? Function()? usernameProvider;

  /// Tên hiển thị đã lưu lúc đăng ký (mock auth giữ `users.name`), để hồ sơ
  /// trong chế độ demo khớp với tên người dùng vừa nhập.
  final String? Function(String username)? nameProvider;

  /// Tên hiển thị theo từng tài khoản, giống một cột `name` trong DB.
  final Map<String, String> _namesByUser = {};
  final Map<String, int> _idsByUser = {};

  /// Với latency 0 phải trả về ngay: `Future.delayed(Duration.zero)` vẫn là
  /// timer của fake async nên sẽ treo widget test nếu chờ nó.
  Future<void> _wait() async {
    if (latency > Duration.zero) {
      await Future.delayed(latency);
    }
  }

  String get _username {
    final value = usernameProvider?.call()?.trim();
    return value == null || value.isEmpty ? 'user1' : value;
  }

  int _idFor(String username) =>
      _idsByUser.putIfAbsent(username, () => _idsByUser.length + 1);

  @override
  Future<UserProfile> fetchProfile() async {
    await _wait();
    final username = _username;
    return UserProfile(
      id: _idFor(username),
      username: username,
      name: _namesByUser[username] ?? nameProvider?.call(username),
    );
  }

  @override
  Future<UserProfile> updateName(String name) async {
    await _wait();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ApiException(400, 'Tên không được để trống');
    }
    if (trimmed.length > 100) {
      throw ApiException(400, 'Tên không được vượt quá 100 ký tự');
    }

    final username = _username;
    _namesByUser[username] = trimmed;
    return UserProfile(
      id: _idFor(username),
      username: username,
      name: trimmed,
    );
  }
}
