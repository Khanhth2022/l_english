import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/network/api_exception.dart';
import 'package:l_english/features/auth/data/models/auth_models.dart';

void main() {
  group('AuthResponse.fromJson', () {
    test('đọc đúng token camelCase và snake_case', () {
      final camel = AuthResponse.fromJson({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresIn': 600,
      });
      expect(camel.accessToken, 'access-1');
      expect(camel.refreshToken, 'refresh-1');
      expect(camel.expiresIn, 600);

      final snake = AuthResponse.fromJson({
        'access_token': 'access-2',
        'refresh_token': 'refresh-2',
        'expires_in': '300',
      });
      expect(snake.accessToken, 'access-2');
      expect(snake.refreshToken, 'refresh-2');
      expect(snake.expiresIn, 300);
    });

    test('từ chối access token thiếu hoặc rỗng', () {
      expect(
        () => AuthResponse.fromJson({'refreshToken': 'refresh-1'}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => AuthResponse.fromJson({
          'accessToken': '   ',
          'refreshToken': 'refresh-1',
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test('từ chối refresh token thiếu hoặc sai kiểu', () {
      expect(
        () => AuthResponse.fromJson({'accessToken': 'access-1'}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => AuthResponse.fromJson({
          'accessToken': 'access-1',
          'refreshToken': 123,
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test('expiresIn sai kiểu thì dùng mặc định 900', () {
      final response = AuthResponse.fromJson({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'expiresIn': 'không phải số',
      });
      expect(response.expiresIn, 900);
    });
  });
}
