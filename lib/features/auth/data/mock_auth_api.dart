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
  final Set<String> _activeRefreshTokens = {};

  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9_.]{3,50}$');

  @override
  Future<AuthResponse> login(String username, String password) async {
    await Future.delayed(latency);
    final user = username.trim();
    if (!_users.containsKey(user) || _users[user] != password) {
      throw ApiException(401, 'Đăng nhập thất bại.');
    }

    final accessToken = 'mock_jwt_access_${user}_${DateTime.now().millisecondsSinceEpoch}';
    final refreshToken = 'mock_jwt_refresh_${user}_${DateTime.now().millisecondsSinceEpoch}';
    _activeRefreshTokens.add(refreshToken);

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: 900,
    );
  }

  @override
  Future<String> register(String username, String password) async {
    await Future.delayed(latency);
    final user = username.trim();

    if (!_usernamePattern.hasMatch(user)) {
      throw ApiException(400, 'Tên đăng nhập phải từ 3–50 ký tự (chỉ chữ cái, số, dấu gạch dưới hoặc chấm).');
    }
    if (password.length < 8) {
      throw ApiException(400, 'Mật khẩu phải có ít nhất 8 ký tự.');
    }
    if (_users.containsKey(user)) {
      throw ApiException(409, 'Tên đăng nhập đã tồn tại.');
    }

    _users[user] = password;
    return 'Tạo tài khoản thành công.';
  }

  @override
  Future<void> logout(String refreshToken) async {
    await Future.delayed(latency);
    _activeRefreshTokens.remove(refreshToken);
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    await Future.delayed(latency);
    if (!_activeRefreshTokens.contains(refreshToken)) {
      throw ApiException(401, 'Phiên đăng nhập hết hạn.');
    }

    _activeRefreshTokens.remove(refreshToken); // Token rotation: xoá token cũ
    final newAccess = 'mock_jwt_access_refreshed_${DateTime.now().millisecondsSinceEpoch}';
    final newRefresh = 'mock_jwt_refresh_rotated_${DateTime.now().millisecondsSinceEpoch}';
    _activeRefreshTokens.add(newRefresh);

    return AuthResponse(
      accessToken: newAccess,
      refreshToken: newRefresh,
      expiresIn: 900,
    );
  }
}
