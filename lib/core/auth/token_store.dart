import 'package:flutter/foundation.dart';

/// Cặp token của một phiên đăng nhập.
@immutable
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Nơi giữ token của phiên đăng nhập.
///
/// Nhánh `feature/words` chỉ *đọc* token để gắn vào header `Authorization`.
/// Khi làm chức năng Đăng nhập, nhánh `feature/auth` thay lớp này bằng bản lưu
/// an toàn trong Keystore (`flutter_secure_storage`) mà không phải sửa
/// `AuthInterceptor`.
abstract class TokenStore extends ChangeNotifier {
  TokenPair? get tokens;

  bool get hasSession => tokens != null;

  Future<void> save(TokenPair pair);

  Future<void> clear();
}

/// Bản lưu tạm trong RAM, dùng khi backend/chức năng đăng nhập chưa xong.
///
/// Token mất khi tắt app, nên có kèm màn hình "Cấu hình kết nối" để dán token
/// thủ công khi cần thử với backend thật.
class InMemoryTokenStore extends TokenStore {
  TokenPair? _tokens;

  @override
  TokenPair? get tokens => _tokens;

  @override
  Future<void> save(TokenPair pair) async {
    _tokens = pair;
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    notifyListeners();
  }
}
