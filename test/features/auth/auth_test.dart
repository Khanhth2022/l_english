import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/auth/token_store.dart';
import 'package:l_english/features/auth/data/mock_auth_api.dart';
import 'package:l_english/features/auth/state/auth_controller.dart';
import 'package:l_english/features/auth/ui/auth_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Auth System (act-01, act-02, act-03, act-04)', () {
    late MockAuthApi api;
    late InMemoryTokenStore tokenStore;
    late AuthController controller;

    setUp(() {
      api = MockAuthApi(latency: Duration.zero);
      tokenStore = InMemoryTokenStore();
      controller = AuthController(api: api, tokenStore: tokenStore);
    });

    test('Đăng nhập thành công với tài khoản mặc định và lưu token', () async {
      final success = await controller.login('user1', 'password123');
      expect(success, isTrue);
      expect(controller.isLoggedIn, isTrue);
      expect(tokenStore.currentUsername, 'user1');
      expect(tokenStore.tokens?.accessToken, startsWith('mock_jwt_access_'));
    });

    test('Đăng nhập thất bại khi sai mật khẩu trả 401', () async {
      final success = await controller.login('user1', 'wrong_pass');
      expect(success, isFalse);
      expect(controller.isLoggedIn, isFalse);
      expect(controller.errorMessage, 'Đăng nhập thất bại');
    });

    test('Đăng ký tài khoản mới thành công và lưu tên hiển thị', () async {
      final success = await controller.register(
        'newuser',
        '12345678',
        name: 'Nguyễn Văn A',
      );
      expect(success, isTrue);
      expect(controller.successMessage, 'Tạo tài khoản thành công');
      expect(api.displayNameOf('newuser'), 'Nguyễn Văn A');

      // Đăng nhập được ngay sau khi tạo
      final loginSuccess = await controller.login('newuser', '12345678');
      expect(loginSuccess, isTrue);
    });

    test('Đăng ký trùng tên đăng nhập trả 409', () async {
      final success = await controller.register(
        'user1',
        '12345678',
        name: 'Nguyễn Văn A',
      );
      expect(success, isFalse);
      expect(controller.errorMessage, 'Tên đăng nhập đã tồn tại');
    });

    test('Đăng ký thiếu tên hiển thị trả 400 như backend', () async {
      final success = await controller.register(
        'newuser',
        '12345678',
        name: '   ',
      );
      expect(success, isFalse);
      expect(controller.errorMessage, 'Tên không được để trống');
    });

    test('Tên hiển thị dài hơn 100 ký tự bị từ chối', () async {
      final success = await controller.register(
        'newuser',
        '12345678',
        name: 'a' * 101,
      );
      expect(success, isFalse);
      expect(controller.errorMessage, 'Tên không được vượt quá 100 ký tự');
    });

    test('Đăng xuất thành công xoá token khỏi store', () async {
      await controller.login('user1', 'password123');
      expect(controller.isLoggedIn, isTrue);

      await controller.logout();
      expect(controller.isLoggedIn, isFalse);
      expect(tokenStore.tokens, isNull);
    });

    test('Làm mới token (rotation) xoá token cũ và cấp token mới', () async {
      final loginRes = await api.login('user1', 'password123');
      final oldRefresh = loginRes.refreshToken;

      final refreshRes = await api.refresh(oldRefresh);
      expect(refreshRes.accessToken, isNotEmpty);
      expect(refreshRes.refreshToken, isNot(equals(oldRefresh)));

      // Dùng lại refresh token cũ bị 401 do rotation
      expect(() => api.refresh(oldRefresh), throwsA(anything));
    });

    testWidgets('tab Tạo tài khoản có ô Tên hiển thị và không tràn layout', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(api: api, tokenStore: tokenStore),
          child: const MaterialApp(home: AuthScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Tên hiển thị'), findsOneWidget);
      expect(find.text('Xác nhận lại mật khẩu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
