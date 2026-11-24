import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/auth/token_store.dart';
import 'package:l_english/core/network/api_exception.dart';
import 'package:l_english/features/auth/data/mock_auth_api.dart';
import 'package:l_english/features/auth/state/auth_controller.dart';
import 'package:l_english/features/auth/ui/change_password_screen.dart';
import 'package:provider/provider.dart';

Future<void> _pumpChangePassword(
  WidgetTester tester, {
  required MockAuthApi api,
  required TokenStore store,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TokenStore>.value(value: store),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(api: api, tokenStore: store),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
                child: const Text('Mở đổi mật khẩu'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở đổi mật khẩu'));
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(
  WidgetTester tester, {
  required String current,
  required String next,
  String? confirm,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), current);
  await tester.enterText(fields.at(1), next);
  await tester.enterText(fields.at(2), confirm ?? next);
  await tester.tap(find.text('Cập nhật mật khẩu'));
  await tester.pumpAndSettle();
}

void main() {
  group('MockAuthApi.changePassword (§2.5)', () {
    late MockAuthApi api;

    setUp(() => api = MockAuthApi(latency: Duration.zero));

    test('đổi thành công thì mật khẩu mới đăng nhập được, mật khẩu cũ bị từ chối', () async {
      await api.login('user1', 'password123');

      final message = await api.changePassword('password123', 'matkhaumoi123');
      expect(message, 'Đổi mật khẩu thành công');

      final session = await api.login('user1', 'matkhaumoi123');
      expect(session.accessToken, isNotEmpty);

      await expectLater(
        api.login('user1', 'password123'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('sai mật khẩu hiện tại trả 400 kèm thông báo của hợp đồng', () async {
      await api.login('user1', 'password123');

      await expectLater(
        api.changePassword('sai_mat_khau', 'matkhaumoi123'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'Mật khẩu hiện tại không đúng',
              ),
        ),
      );
    });

    test('mật khẩu mới trùng mật khẩu cũ bị từ chối', () async {
      await api.login('user1', 'password123');

      await expectLater(
        api.changePassword('password123', 'password123'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Mật khẩu mới phải khác mật khẩu hiện tại',
          ),
        ),
      );
    });

    test('mật khẩu mới ngắn hơn 8 ký tự bị từ chối', () async {
      await api.login('user1', 'password123');

      await expectLater(
        api.changePassword('password123', 'ngan'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Mật khẩu mới phải có ít nhất 8 ký tự',
          ),
        ),
      );
    });

    test('thu hồi mọi refresh token của tài khoản, phiên khác không gia hạn được', () async {
      final session = await api.login('user1', 'password123');
      await api.changePassword('password123', 'matkhaumoi123');

      await expectLater(
        api.refresh(session.refreshToken),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('chưa đăng nhập thì không đổi được mật khẩu', () async {
      await expectLater(
        api.changePassword('password123', 'matkhaumoi123'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('AuthController.changePassword', () {
    test('thành công thì đặt successMessage và tắt isLoading', () async {
      final api = MockAuthApi(latency: Duration.zero);
      final store = InMemoryTokenStore();
      final controller = AuthController(api: api, tokenStore: store);
      await controller.login('user1', 'password123');

      final ok = await controller.changePassword('password123', 'matkhaumoi123');

      expect(ok, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.successMessage, 'Đổi mật khẩu thành công');
      expect(controller.errorMessage, isNull);
      // Phiên hiện tại vẫn còn: access token chưa hết hạn.
      expect(store.hasSession, isTrue);
    });

    test('thất bại thì đặt errorMessage đúng thông báo backend', () async {
      final api = MockAuthApi(latency: Duration.zero);
      final store = InMemoryTokenStore();
      final controller = AuthController(api: api, tokenStore: store);
      await controller.login('user1', 'password123');

      final ok = await controller.changePassword('sai', 'matkhaumoi123');

      expect(ok, isFalse);
      expect(controller.errorMessage, 'Mật khẩu hiện tại không đúng');
    });
  });

  group('ChangePasswordScreen', () {
    testWidgets('gửi hai mật khẩu, báo thành công và đóng màn hình', (tester) async {
      final api = MockAuthApi(latency: Duration.zero);
      final store = InMemoryTokenStore();
      await api.login('user1', 'password123');

      await _pumpChangePassword(tester, api: api, store: store);
      await _fillAndSubmit(
        tester,
        current: 'password123',
        next: 'matkhaumoi123',
      );

      expect(find.text('Đổi mật khẩu thành công'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsNothing);
    });

    testWidgets('chặn khi mật khẩu xác nhận không khớp', (tester) async {
      final api = MockAuthApi(latency: Duration.zero);
      final store = InMemoryTokenStore();
      await api.login('user1', 'password123');

      await _pumpChangePassword(tester, api: api, store: store);
      await _fillAndSubmit(
        tester,
        current: 'password123',
        next: 'matkhaumoi123',
        confirm: 'khac_nhau_123',
      );

      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('hiển thị nguyên văn lỗi sai mật khẩu hiện tại từ máy chủ', (tester) async {
      final api = MockAuthApi(latency: Duration.zero);
      final store = InMemoryTokenStore();
      await api.login('user1', 'password123');

      await _pumpChangePassword(tester, api: api, store: store);
      await _fillAndSubmit(
        tester,
        current: 'sai_mat_khau',
        next: 'matkhaumoi123',
      );

      expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });
  });
}
