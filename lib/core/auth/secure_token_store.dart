import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// Lưu token vào Keychain (iOS) / EncryptedSharedPreferences (Android) để
/// phiên đăng nhập không bị mất khi tắt ứng dụng.
class SecureTokenStore extends TokenStore {
  SecureTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'lenglish_access_token';
  static const String _refreshKey = 'lenglish_refresh_token';
  static const String _usernameKey = 'lenglish_username';

  TokenPair? _tokens;
  String? _username;

  @override
  TokenPair? get tokens => _tokens;

  @override
  String? get currentUsername => _username;

  /// Đọc lại phiên đã lưu. Gọi một lần trước khi chạy ứng dụng.
  Future<void> restore() async {
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      if (access != null &&
          access.isNotEmpty &&
          refresh != null &&
          refresh.isNotEmpty) {
        _tokens = TokenPair(accessToken: access, refreshToken: refresh);
      } else {
        _tokens = null;
      }
      _username = await _storage.read(key: _usernameKey);
    } catch (error) {
      // Khoá bảo mật hỏng hoặc thiết bị không hỗ trợ: coi như chưa đăng nhập.
      debugPrint('SecureTokenStore: không đọc được phiên đã lưu ($error).');
      _tokens = null;
      _username = null;
    }
  }

  @override
  Future<void> save(TokenPair pair, {String? username}) async {
    if (pair.accessToken.isEmpty || pair.refreshToken.isEmpty) {
      throw ArgumentError('Token không được để trống.');
    }
    _tokens = pair;
    if (username != null) {
      _username = username;
    }
    notifyListeners();

    try {
      await _storage.write(key: _accessKey, value: pair.accessToken);
      await _storage.write(key: _refreshKey, value: pair.refreshToken);
      if (username != null) {
        await _storage.write(key: _usernameKey, value: username);
      }
    } catch (error) {
      debugPrint('SecureTokenStore: không ghi được token ($error).');
    }
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    _username = null;
    notifyListeners();

    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
      await _storage.delete(key: _usernameKey);
    } catch (error) {
      debugPrint('SecureTokenStore: không xoá được token ($error).');
    }
  }
}
