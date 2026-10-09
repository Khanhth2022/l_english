class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn = 900,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: (json['accessToken'] ?? json['access_token'] ?? '') as String,
      refreshToken: (json['refreshToken'] ?? json['refresh_token'] ?? '') as String,
      expiresIn: (json['expiresIn'] ?? json['expires_in'] ?? 900) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
  };
}
