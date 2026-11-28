import 'dart:convert';

import 'package:flutter/foundation.dart';

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

  /// Email → username: backend tra tài khoản theo email đã chuẩn hoá
  /// (trim + chữ thường). Hai tài khoản mẫu có email để thử luồng quên mật
  /// khẩu; tài khoản tạo qua `confirmRegistration` cũng được ghi vào đây nên
  /// khôi phục mật khẩu hoạt động với mọi tài khoản đã xác thực.
  final Map<String, String> _emails = {
    'user1@example.com': 'user1',
    'khanh@example.com': 'khanh',
  };

  /// Bản nháp đăng ký chưa xác thực, khoá theo email đã chuẩn hoá — đúng bảng
  /// `pending_registrations` bên backend: mỗi email chỉ một bản nháp sống.
  final Map<String, _MockPendingRegistration> _pendingRegistrations = {};

  /// Mã đăng ký cố định để thử luồng khi không đọc được email thật.
  static const String debugRegistrationCode = '123456';

  /// Mã đăng ký sống 10 phút theo `app.otp.registration-ttl` của backend.
  static const Duration registrationCodeTtl = Duration(minutes: 10);

  /// Sai đủ 5 lần thì bản nháp bị xoá (`app.otp.max-attempts`).
  static const int registrationMaxAttempts = 5;

  /// Mã đặt lại mật khẩu còn sống của từng tài khoản — mỗi user chỉ một mã,
  /// giống ràng buộc UNIQUE user_id của bảng `password_reset_codes`.
  final Map<String, _MockResetCode> _resetCodes = {};

  /// Mock dùng mã cố định để thử được luồng mà không đọc được email; backend
  /// thật sinh 6 số bằng SecureRandom.
  static const String debugResetCode = '123456';

  /// Mã sống 15 phút, đúng cấu hình `app.password-reset.ttl` của backend.
  static const Duration resetCodeTtl = Duration(minutes: 15);

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _codePattern = RegExp(r'^[0-9]{6}$');

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

  /// §5.1 — bước 1: chỉ ghi bản nháp, chưa tạo tài khoản và chưa cấp token.
  ///
  /// Thứ tự kiểm tra bám backend: ràng buộc form → trùng username → trùng
  /// email → username đang bị bản nháp của email khác giữ. Gọi lại với cùng
  /// email là gửi lại mã: ghi đè bản nháp tại chỗ, reset attempts, mã cũ chết.
  @override
  Future<String> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await _wait();
    // Canonical chữ thường: không cho tồn tại song song "Uyenne" và "uyenne".
    final user = username.trim().toLowerCase();
    final displayName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (displayName.isEmpty) {
      throw ApiException(400, 'Tên không được để trống');
    }
    if (displayName.length > 100) {
      throw ApiException(400, 'Tên không được vượt quá 100 ký tự');
    }
    if (user.length < 3 || user.length > 50) {
      throw ApiException(400, 'Tên đăng nhập phải từ 3 đến 50 ký tự');
    }
    if (!_usernamePattern.hasMatch(user)) {
      throw ApiException(
        400,
        'Tên đăng nhập chỉ được chứa chữ cái, số, dấu chấm và gạch dưới',
      );
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw ApiException(400, 'Email không hợp lệ');
    }
    if (password.length < 8) {
      throw ApiException(400, 'Mật khẩu phải có ít nhất 8 ký tự');
    }
    if (utf8.encode(password).length > 72) {
      throw ApiException(400, 'Mật khẩu không được vượt quá 72 byte');
    }

    if (_users.containsKey(user)) {
      throw ApiException(409, 'Tên đăng nhập đã tồn tại');
    }
    if (_emails.containsKey(normalizedEmail)) {
      throw ApiException(409, 'Email này đã được sử dụng');
    }
    final heldByAnotherMailbox = _pendingRegistrations.entries.any(
      (entry) => entry.value.username == user && entry.key != normalizedEmail,
    );
    if (heldByAnotherMailbox) {
      throw ApiException(409, 'Tên đăng nhập đã tồn tại');
    }

    _pendingRegistrations[normalizedEmail] = _MockPendingRegistration(
      name: displayName,
      username: user,
      password: password,
      code: debugRegistrationCode,
      expiresAt: DateTime.now().add(registrationCodeTtl),
    );
    debugPrint(
      'MockAuthApi: mã xác thực đăng ký của $normalizedEmail là '
      '$debugRegistrationCode',
    );
    return 'Mã xác thực đã được gửi tới email';
  }

  /// §5.1 — bước 2: mã đúng thì tạo tài khoản và xoá bản nháp; không cấp
  /// token. Mã sai tăng `attempts`, đủ 5 lần thì bản nháp chết; mã hết hạn
  /// cũng xoá bản nháp luôn, đúng `RegistrationTxService`.
  @override
  Future<String> confirmRegistration(String email, String code) async {
    await _wait();
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      throw ApiException(400, 'Email không hợp lệ');
    }
    if (!_codePattern.hasMatch(code.trim())) {
      throw ApiException(400, 'Mã xác thực phải gồm 6 chữ số');
    }

    final draft = _pendingRegistrations[normalizedEmail];
    if (draft == null) {
      throw ApiException(400, 'Mã xác thực không đúng hoặc đã hết hạn');
    }
    if (draft.isExpired) {
      _pendingRegistrations.remove(normalizedEmail);
      throw ApiException(400, 'Mã xác thực không đúng hoặc đã hết hạn');
    }
    if (draft.code != code.trim()) {
      draft.attempts += 1;
      if (draft.attempts >= registrationMaxAttempts) {
        _pendingRegistrations.remove(normalizedEmail);
      }
      throw ApiException(400, 'Mã xác thực không đúng hoặc đã hết hạn');
    }
    // Trong lúc chờ mã, username/email có thể đã bị người khác chiếm: backend
    // để UNIQUE key bắt và trả 409 đúng như bước 1.
    if (_users.containsKey(draft.username)) {
      _pendingRegistrations.remove(normalizedEmail);
      throw ApiException(409, 'Tên đăng nhập đã tồn tại');
    }
    if (_emails.containsKey(normalizedEmail)) {
      _pendingRegistrations.remove(normalizedEmail);
      throw ApiException(409, 'Email này đã được sử dụng');
    }

    _users[draft.username] = draft.password;
    _names[draft.username] = draft.name;
    _emails[normalizedEmail] = draft.username;
    _pendingRegistrations.remove(normalizedEmail);
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
  Future<String> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _wait();

    final user = _sessionUser;
    if (user == null || !_users.containsKey(user)) {
      throw ApiException(
        401,
        'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
      );
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

  /// §2.6 — bước 1: yêu cầu mã. Email lạ vẫn trả đúng câu và đúng 200, đúng
  /// hành vi chống dò tài khoản của backend.
  @override
  Future<String> forgotPassword(String email) async {
    await _wait();
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) {
      throw ApiException(400, 'Email không hợp lệ');
    }

    final user = _emails[normalized];
    if (user != null) {
      // Gửi lại bất cứ lúc nào: mã mới ghi đè mã cũ, kể cả mã đã hết hạn.
      _resetCodes[user] = _MockResetCode(
        code: debugResetCode,
        expiresAt: DateTime.now().add(resetCodeTtl),
      );
      debugPrint(
        'MockAuthApi: mã đặt lại mật khẩu của $normalized là $debugResetCode',
      );
    }

    return 'Nếu email này đã đăng ký, mã xác thực đã được gửi tới email đó';
  }

  /// §2.6 — bước 2: đặt lại mật khẩu. Kiểm tra đúng thứ tự backend: ràng buộc
  /// body → có tài khoản → khác mật khẩu cũ → mã còn hạn và khớp.
  @override
  Future<String> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    await _wait();
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) {
      throw ApiException(400, 'Email không hợp lệ');
    }
    if (!_codePattern.hasMatch(code)) {
      throw ApiException(400, 'Mã xác thực phải gồm 6 chữ số');
    }
    if (newPassword.length < 8) {
      throw ApiException(400, 'Mật khẩu phải có ít nhất 8 ký tự');
    }
    if (utf8.encode(newPassword).length > 72) {
      throw ApiException(400, 'Mật khẩu không được vượt quá 72 byte');
    }

    final user = _emails[normalized];
    if (user == null) {
      throw ApiException(400, 'Mã xác thực không đúng hoặc đã hết hạn');
    }
    if (_users[user] == newPassword) {
      throw ApiException(400, 'Mật khẩu mới phải khác mật khẩu hiện tại');
    }

    final resetCode = _resetCodes[user];
    if (resetCode == null || resetCode.isExpired) {
      _resetCodes.remove(user);
      throw ApiException(400, 'Mã xác thực không đúng hoặc đã hết hạn');
    }
    if (resetCode.code != code.trim()) {
      resetCode.attempts += 1;
      // Sai đủ 5 lần thì huỷ mã, người dùng phải yêu cầu lại từ bước 1.
      if (resetCode.attempts >= 5) _resetCodes.remove(user);
      throw ApiException(400, 'Mã xác thực không đúng hoặc đã hết hạn');
    }

    _users[user] = newPassword;
    _resetCodes.remove(user);
    // Thu hồi mọi phiên: refresh token cũ không gia hạn được nữa.
    _refreshTokenOwners.removeWhere((_, owner) => owner == user);
    _sessionUser = null;
    return 'Đặt lại mật khẩu thành công';
  }

  bool _isValidEmail(String email) =>
      email.length <= 254 && _emailPattern.hasMatch(email);
}

/// Mã đặt lại mật khẩu trong bộ nhớ của mock.
///
/// Backend chỉ lưu SHA-256 của mã; mock giữ nguyên mã để so khớp và đếm số
/// lần nhập sai như cột `attempts`.
class _MockResetCode {
  _MockResetCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
  int attempts = 0;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Bản nháp đăng ký trong bộ nhớ của mock (`pending_registrations`).
///
/// Backend lưu mật khẩu dạng BCrypt và mã dạng SHA-256; mock giữ nguyên cả hai
/// để so khớp, đếm `attempts` và trả đúng câu lỗi như thật.
class _MockPendingRegistration {
  _MockPendingRegistration({
    required this.name,
    required this.username,
    required this.password,
    required this.code,
    required this.expiresAt,
  });

  final String name;
  final String username;
  final String password;
  final String code;
  final DateTime expiresAt;
  int attempts = 0;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
