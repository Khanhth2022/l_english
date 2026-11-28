import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/auth/token_store.dart';
import 'package:l_english/core/network/api_exception.dart';
import 'package:l_english/features/auth/data/mock_auth_api.dart';
import 'package:l_english/features/auth/state/auth_controller.dart';
import 'package:l_english/features/auth/ui/auth_screen.dart';
import 'package:l_english/features/auth/ui/forgot_password_screen.dart';
import 'package:l_english/features/auth/ui/reset_password_screen.dart';
import 'package:provider/provider.dart';

const _genericResetMessage =
    'Nếu email này đã đăng ký, mã xác thực đã được gửi tới email đó';

Future<void> _pumpForgotPassword(
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
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
                child: const Text('Mở quên mật khẩu'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở quên mật khẩu'));
  await tester.pumpAndSettle();
}

Future<void> _requestCode(
  WidgetTester tester, {
  String email = 'user1@example.com',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.tap(find.text('Gửi mã xác thực'));
  await tester.pumpAndSettle();
}

void main() {
  group('AuthScreen — liên kết quên mật khẩu', () {
    testWidgets('bấm "Quên mật khẩu?" mở màn hình yêu cầu mã', (tester) async {
      final store = InMemoryTokenStore();
      final api = MockAuthApi(latency: Duration.zero);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Dio?>.value(value: null),
            ChangeNotifierProvider<TokenStore>.value(value: store),
            ChangeNotifierProvider<AuthController>(
              create: (_) => AuthController(api: api, tokenStore: store),
            ),
          ],
          child: const MaterialApp(home: AuthScreen()),
        ),
      );

      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });
  });

  group('MockAuthApi.forgotPassword (§2.6 — bước 1)', () {
    late MockAuthApi api;

    setUp(() => api = MockAuthApi(latency: Duration.zero));

    test('email có tài khoản trả đúng một câu thông báo chung', () async {
      expect(
        await api.forgotPassword('user1@example.com'),
        _genericResetMessage,
      );
    });

    test(
      'email lạ cũng trả cùng câu, không lộ tài khoản có tồn tại hay không',
      () async {
        expect(
          await api.forgotPassword('khong_ton_tai@example.com'),
          _genericResetMessage,
        );
      },
    );

    test('email sai định dạng bị từ chối 400 như @Email của backend', () async {
      await expectLater(
        api.forgotPassword('khong-phai-email'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Email không hợp lệ'),
        ),
      );
    });
  });

  group('MockAuthApi.resetPassword (§2.6 — bước 2)', () {
    late MockAuthApi api;

    setUp(() => api = MockAuthApi(latency: Duration.zero));

    test('mã đúng đổi mật khẩu: mật khẩu mới đăng nhập được, mật khẩu cũ bị từ chối', () async {
      await api.forgotPassword('user1@example.com');

      final message = await api.resetPassword(
        'user1@example.com',
        MockAuthApi.debugResetCode,
        'matkhaumoi123',
      );
      expect(message, 'Đặt lại mật khẩu thành công');

      final session = await api.login('user1', 'matkhaumoi123');
      expect(session.accessToken, isNotEmpty);

      await expectLater(
        api.login('user1', 'password123'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('email hoa/thường và khoảng trắng vẫn khớp tài khoản', () async {
      await api.forgotPassword('  USER1@Example.com ');

      final message = await api.resetPassword(
        ' USER1@Example.com ',
        MockAuthApi.debugResetCode,
        'matkhaumoi123',
      );
      expect(message, 'Đặt lại mật khẩu thành công');
    });

    test('mã sai trả 400 đúng câu của hợp đồng', () async {
      await api.forgotPassword('user1@example.com');

      await expectLater(
        api.resetPassword('user1@example.com', '000000', 'matkhaumoi123'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'Mã xác thực không đúng hoặc đã hết hạn',
              ),
        ),
      );
    });

    test('chưa yêu cầu mã thì đặt lại bị từ chối', () async {
      await expectLater(
        api.resetPassword(
          'user1@example.com',
          MockAuthApi.debugResetCode,
          'matkhaumoi123',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Mã xác thực không đúng hoặc đã hết hạn',
          ),
        ),
      );
    });

    test('mật khẩu mới trùng mật khẩu cũ bị từ chối', () async {
      await api.forgotPassword('user1@example.com');

      await expectLater(
        api.resetPassword(
          'user1@example.com',
          MockAuthApi.debugResetCode,
          'password123',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Mật khẩu mới phải khác mật khẩu hiện tại',
          ),
        ),
      );
    });

    test('mã chỉ dùng một lần: đặt lại lần hai với cùng mã thất bại', () async {
      await api.forgotPassword('user1@example.com');
      await api.resetPassword(
        'user1@example.com',
        MockAuthApi.debugResetCode,
        'matkhaumoi123',
      );

      await expectLater(
        api.resetPassword(
          'user1@example.com',
          MockAuthApi.debugResetCode,
          'matkhaumoi456',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Mã xác thực không đúng hoặc đã hết hạn',
          ),
        ),
      );
    });

    test(
      'sai mã 5 lần thì mã bị huỷ, mã đúng sau đó cũng không dùng được',
      () async {
        await api.forgotPassword('user1@example.com');
        for (var attempt = 0; attempt < 5; attempt++) {
          await expectLater(
            api.resetPassword('user1@example.com', '000000', 'matkhaumoi123'),
            throwsA(isA<ApiException>()),
          );
        }

        await expectLater(
          api.resetPassword(
            'user1@example.com',
            MockAuthApi.debugResetCode,
            'matkhaumoi123',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Mã xác thực không đúng hoặc đã hết hạn',
            ),
          ),
        );
      },
    );

    test(
      'thu hồi mọi refresh token: phiên cũ không gia hạn được nữa',
      () async {
        final session = await api.login('user1', 'password123');
        await api.forgotPassword('user1@example.com');
        await api.resetPassword(
          'user1@example.com',
          MockAuthApi.debugResetCode,
          'matkhaumoi123',
        );

        await expectLater(
          api.refresh(session.refreshToken),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      },
    );

    test('email không có tài khoản trả 400 khi đặt lại', () async {
      await api.forgotPassword('khong_ton_tai@example.com');

      await expectLater(
        api.resetPassword(
          'khong_ton_tai@example.com',
          MockAuthApi.debugResetCode,
          'matkhaumoi123',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Mã xác thực không đúng hoặc đã hết hạn',
          ),
        ),
      );
    });
  });

  group('AuthController quên mật khẩu', () {
    test(
      'forgotPassword thành công đặt successMessage và tắt isLoading',
      () async {
        final api = MockAuthApi(latency: Duration.zero);
        final controller = AuthController(
          api: api,
          tokenStore: InMemoryTokenStore(),
        );

        final ok = await controller.forgotPassword('user1@example.com');

        expect(ok, isTrue);
        expect(controller.isLoading, isFalse);
        expect(controller.successMessage, _genericResetMessage);
        expect(controller.errorMessage, isNull);
      },
    );

    test('forgotPassword thất bại đặt errorMessage đúng câu backend', () async {
      final api = MockAuthApi(latency: Duration.zero);
      final controller = AuthController(
        api: api,
        tokenStore: InMemoryTokenStore(),
      );

      final ok = await controller.forgotPassword('khong-phai-email');

      expect(ok, isFalse);
      expect(controller.errorMessage, 'Email không hợp lệ');
    });

    test('resetPassword thành công đặt successMessage của máy chủ', () async {
      final api = MockAuthApi(latency: Duration.zero);
      final controller = AuthController(
        api: api,
        tokenStore: InMemoryTokenStore(),
      );
      await controller.forgotPassword('user1@example.com');

      final ok = await controller.resetPassword(
        'user1@example.com',
        MockAuthApi.debugResetCode,
        'matkhaumoi123',
      );

      expect(ok, isTrue);
      expect(controller.successMessage, 'Đặt lại mật khẩu thành công');
      expect(controller.errorMessage, isNull);
    });

    test('resetPassword sai mã đặt errorMessage', () async {
      final api = MockAuthApi(latency: Duration.zero);
      final controller = AuthController(
        api: api,
        tokenStore: InMemoryTokenStore(),
      );
      await controller.forgotPassword('user1@example.com');

      final ok = await controller.resetPassword(
        'user1@example.com',
        '000000',
        'matkhaumoi123',
      );

      expect(ok, isFalse);
      expect(controller.errorMessage, 'Mã xác thực không đúng hoặc đã hết hạn');
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('gửi email hợp lệ thì chuyển sang bước nhập mã', (
      tester,
    ) async {
      final api = MockAuthApi(latency: Duration.zero);
      await _pumpForgotPassword(tester, api: api, store: InMemoryTokenStore());

      await _requestCode(tester);

      expect(
        find.byType(ForgotPasswordScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });

    testWidgets('chặn email sai định dạng trước khi gọi máy chủ', (
      tester,
    ) async {
      final api = MockAuthApi(latency: Duration.zero);
      await _pumpForgotPassword(tester, api: api, store: InMemoryTokenStore());

      await _requestCode(tester, email: 'khong-phai-email');

      expect(find.text('Email không hợp lệ.'), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsNothing);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets(
      'mã đúng đặt lại mật khẩu, đóng cả hai màn và không giữ phiên cũ',
      (tester) async {
        final api = MockAuthApi(latency: Duration.zero);
        final store = InMemoryTokenStore();
        await _pumpForgotPassword(tester, api: api, store: store);
        await _requestCode(tester);

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), MockAuthApi.debugResetCode);
        await tester.enterText(fields.at(1), 'matkhaumoi123');
        await tester.enterText(fields.at(2), 'matkhaumoi123');
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ResetPasswordScreen), findsNothing);
        expect(find.byType(ForgotPasswordScreen), findsNothing);
        expect(store.hasSession, isFalse);

        final session = await api.login('user1', 'matkhaumoi123');
        expect(session.accessToken, isNotEmpty);
      },
    );

    testWidgets('chặn khi mật khẩu xác nhận không khớp', (tester) async {
      final api = MockAuthApi(latency: Duration.zero);
      await _pumpForgotPassword(tester, api: api, store: InMemoryTokenStore());
      await _requestCode(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), MockAuthApi.debugResetCode);
      await tester.enterText(fields.at(1), 'matkhaumoi123');
      await tester.enterText(fields.at(2), 'khac_nhau_123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });

    testWidgets('hiển thị nguyên văn lỗi mã sai từ máy chủ', (tester) async {
      final api = MockAuthApi(latency: Duration.zero);
      await _pumpForgotPassword(tester, api: api, store: InMemoryTokenStore());
      await _requestCode(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '000000');
      await tester.enterText(fields.at(1), 'matkhaumoi123');
      await tester.enterText(fields.at(2), 'matkhaumoi123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      expect(
        find.text('Mã xác thực không đúng hoặc đã hết hạn'),
        findsOneWidget,
      );
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });
  });
}
