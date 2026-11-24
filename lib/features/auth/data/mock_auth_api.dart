import '../../../core/network/api_exception.dart';
import 'auth_api.dart';
import 'models/auth_models.dart';

/// Giả lập hệ thống xác thực Auth in-memory khi chạy mà không cần Spring Boot backend.
class MockAuthApi implements AuthApi {
  MockAuthApi({this.latency = const Duration(milliseconds: 300)}) {
    // Tài khoản thử nghiệm mặc định
    _users['user1'] = 'password123';
    _users['khanh'] = '12345678';
  }

  final Duration latency;
  final Map<String, String> _users = {};

  /// Tên hiển thị theo từng tài khoản (cột `users.name` bên backend).
  final Map<String, String> _names = {};

  /// refresh token → username sở hữu, để thu hồi đúng phiên của một tài khoản.
  final Map<String, String> _refreshTokenOwners = {};

  /// Tài khoản của phiên hiện tại: backend lấy từ Bearer token, mock giữ lại
  /// user đăng nhập gần nhất (đăng xuất thì xoá).
  String? _sessionUser;

  /// Tên hiển thị đã lưu của một tài khoản (dùng cho test và màn hồ sơ).
  String? displayNameOf(String username) =>
      _names[username.trim().toLowerCase()];

  /// Bộ đếm giúp hai token phát trong cùng một mili-giây vẫn khác nhau —
  /// rotation phải luôn cho ra refresh token mới, kể cả khi đồng hồ chưa nhích.
  int _tokenSequence = 0;

  String _issueToken(String kind, String user) =>
      'mock_jwt_${kind}_${user}_${DateTime.now().millisecondsSinceEpoch}_${_tokenSequence++}';

  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9_.]{3,50}$');

  /// Độ trễ giả lập. Với latency 0 phải trả về ngay: trong widget test
  /// `Future.delayed(Duration.zero)` vẫn là một timer của fake async và chỉ
  /// chạy khi test pump thời gian, nên chờ nó sẽ treo test.
  Future<void> _wait() async {
    if (latency > Duration.zero) {
      await Future.delayed(latency);
    }
  }

  @override
  Future<AuthResponse> login(String username, String password) async {
    await _wait();
    final user = username.trim().toLowerCase();
    if (!_users.containsKey(user) || _users[user] != password) {
      throw ApiException(401, 'Đăng nhập thất bại');
    }

    final accessToken = _issueToken('access', user);
    final refreshToken = _issueToken('refresh', user);
    _refreshTokenOwners[refreshToken] = user;
    _sessionUser = user;

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: 900,
    );
  }

  @override
  Future<String> register(
    String username,
    String password, {
    required String name,
  }) async {
    await _wait();
    // Canonical chữ thường: không cho tồn tại song song "Uyenne" và "uyenne".
    final user = username.trim().toLowerCase();
    final displayName = name.trim();

    // Thứ tự kiểm tra và câu chữ bám RegisterForm của backend (feature/name).
    if (displayName.isEmpty) {
      throw ApiException(400, 'Tên không được để trống');
    }
    if (displayName.length > 100) {
      throw ApiException(400, 'Tên không được vượt quá 100 ký tự');
    }
    if (!_usernamePattern.hasMatch(user)) {
      throw ApiException(400, 'Tên đăng nhập phải từ 3 đến 50 ký tự');
    }
    if (password.length < 8) {
      throw ApiException(400, 'Mật khẩu phải có ít nhất 8 ký tự');
    }
    if (_users.containsKey(user)) {
      throw ApiException(409, 'Tên đăng nhập đã tồn tại');
    }

    _users[user] = password;
    _names[user] = displayName;
    return 'Tạo tài khoản thành công';
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _wait();
    final owner = _refreshTokenOwners.remove(refreshToken);
    if (owner != null && !_refreshTokenOwners.containsValue(owner)) {
      _sessionUser = null;
    }
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    await _wait();
    final owner = _refreshTokenOwners.remove(refreshToken);
    if (owner == null) {
      throw ApiException(401, 'Phiên đăng nhập hết hạn');
    }

    final newAccess = _issueToken('access', owner);
    final newRefresh = _issueToken('refresh', owner);
    _refreshTokenOwners[newRefresh] = owner;

    return AuthResponse(
      accessToken: newAccess,
      refreshToken: newRefresh,
      expiresIn: 900,
    );
  }

  /// §2.5 — kiểm tra đúng thứ tự backend: ràng buộc body, sai mật khẩu hiện
  /// tại, rồi dùng lại mật khẩu cũ. Thành công thì thu hồi mọi refresh token
  /// của tài khoản, giống `PasswordTxService` bên Spring Boot.
  @override
  Future<String> changePassword(String currentPassword, String newPassword) async {
    await _wait();

    final user = _sessionUser;
    if (user == null || !_users.containsKey(user)) {
      throw ApiException(401, 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
    }
    if (newPassword.length < 8) {
      throw ApiException(400, 'Mật khẩu mới phải có ít nhất 8 ký tự');
    }
    if (_users[user] != currentPassword) {
      throw ApiException(400, 'Mật khẩu hiện tại không đúng');
    }
    if (currentPassword == newPassword) {
      throw ApiException(400, 'Mật khẩu mới phải khác mật khẩu hiện tại');
    }

    _users[user] = newPassword;
    _refreshTokenOwners.removeWhere((_, owner) => owner == user);
    return 'Đổi mật khẩu thành công';
  }
}
