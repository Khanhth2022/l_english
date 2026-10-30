import '../../../../core/network/api_exception.dart';

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn = 900,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  /// Đọc phản hồi đăng nhập/refresh và từ chối token rỗng hoặc sai kiểu.
  ///
  /// Trước đây thiếu key thì trả chuỗi rỗng, khiến ứng dụng coi như đã đăng
  /// nhập trong khi mọi request sau đó đều 401.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final accessToken = _readToken(json['accessToken'] ?? json['access_token']);
    if (accessToken == null) {
      throw ApiException(0, 'Máy chủ không trả về access token hợp lệ.');
    }

    final refreshToken = _readToken(
      json['refreshToken'] ?? json['refresh_token'],
    );
    if (refreshToken == null) {
      throw ApiException(0, 'Máy chủ không trả về refresh token hợp lệ.');
    }

    final rawExpires = json['expiresIn'] ?? json['expires_in'];
    final parsedExpires = rawExpires is int
        ? rawExpires
        : int.tryParse('$rawExpires');
    final expiresIn = parsedExpires != null && parsedExpires > 0
        ? parsedExpires
        : 900;

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
  };
}

String? _readToken(Object? value) {
  if (value is! String) return null;
  final token = value.trim();
  return token.isEmpty ? null : token;
}
