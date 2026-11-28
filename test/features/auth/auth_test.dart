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

    test('Đăng ký bước 1 chỉ ghi bản nháp, chưa đăng nhập được', () async {
      final success = await controller.register(
        name: 'Nguyễn Văn A',
        username: 'newuser',
        email: 'newuser@example.com',
        password: '12345678',
      );
      expect(success, isTrue);
      expect(controller.successMessage, 'Mã xác thực đã được gửi tới email');

      // Chưa xác thực thì users chưa có dòng nào: đăng nhập phải thất bại.
      final loginBefore = await controller.login('newuser', '12345678');
      expect(loginBefore, isFalse);
      expect(controller.errorMessage, 'Đăng nhập thất bại');
    });

    test('Xác thực mã đúng tạo tài khoản và đăng nhập được', () async {
      await controller.register(
        name: 'Nguyễn Văn A',
        username: 'newuser',
        email: 'newuser@example.com',
        password: '12345678',
      );

      final confirmed = await controller.confirmRegistration(
        'newuser@example.com',
        MockAuthApi.debugRegistrationCode,
      );
      expect(confirmed, isTrue);
      expect(controller.successMessage, 'Tạo tài khoản thành công');
      expect(api.displayNameOf('newuser'), 'Nguyễn Văn A');

      // Đăng nhập bằng username, không phải email.
      expect(await controller.login('newuser', '12345678'), isTrue);
    });

    test('Xác thực sai mã trả 400 và tài khoản vẫn chưa tồn tại', () async {
      await controller.register(
        name: 'Nguyễn Văn A',
        username: 'newuser',
        email: 'newuser@example.com',
        password: '12345678',
      );

      expect(
        await controller.confirmRegistration('newuser@example.com', '000000'),
        isFalse,
      );
      expect(controller.errorMessage, 'Mã xác thực không đúng hoặc đã hết hạn');
      expect(await controller.login('newuser', '12345678'), isFalse);
    });

    test('Đăng ký trùng tên đăng nhập trả 409', () async {
      final success = await controller.register(
        name: 'Nguyễn Văn A',
        username: 'user1',
        email: 'khac@example.com',
        password: '12345678',
      );
      expect(success, isFalse);
      expect(controller.errorMessage, 'Tên đăng nhập đã tồn tại');
    });

    test('Đăng ký trùng email trả 409', () async {
      final success = await controller.register(
        name: 'Nguyễn Văn A',
        username: 'newuser',
        email: 'user1@example.com',
        password: '12345678',
      );
      expect(success, isFalse);
      expect(controller.errorMessage, 'Email này đã được sử dụng');
    });

    test('Đăng ký thiếu tên hiển thị trả 400 như backend', () async {
      final success = await controller.register(
        name: '   ',
        username: 'newuser',
        email: 'newuser@example.com',
        password: '12345678',
      );
      expect(success, isFalse);
      expect(controller.errorMessage, 'Tên không được để trống');
    });

    test('Tên hiển thị dài hơn 100 ký tự bị từ chối', () async {
      final success = await controller.register(
        name: 'a' * 101,
        username: 'newuser',
        email: 'newuser@example.com',
        password: '12345678',
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

    testWidgets('tab Tạo tài khoản có ô Tên hiển thị và không tràn layout', (
      tester,
    ) async {
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
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Xác nhận lại mật khẩu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
