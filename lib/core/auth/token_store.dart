import 'package:flutter/foundation.dart';

/// Cặp token của một phiên đăng nhập.
@immutable
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Nơi giữ token của phiên đăng nhập.
abstract class TokenStore extends ChangeNotifier {
  TokenPair? get tokens;

  String? get currentUsername;

  bool get hasSession => tokens != null;

  Future<void> save(TokenPair pair, {String? username});

  Future<void> clear();
}

/// Bản lưu tạm trong bộ nhớ, hỗ trợ lưu trữ token và tên người dùng hiện tại.
class InMemoryTokenStore extends TokenStore {
  TokenPair? _tokens;
  String? _username;

  @override
  TokenPair? get tokens => _tokens;

  @override
  String? get currentUsername => _username;

  @override
  Future<void> save(TokenPair pair, {String? username}) async {
    _tokens = pair;
    if (username != null) {
      _username = username;
    }
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    _username = null;
    notifyListeners();
  }
}
