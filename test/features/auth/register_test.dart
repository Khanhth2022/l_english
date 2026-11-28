import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/auth/token_store.dart';
import 'package:l_english/features/auth/data/mock_auth_api.dart';
import 'package:l_english/features/auth/state/auth_controller.dart';
import 'package:l_english/features/auth/ui/auth_screen.dart';
import 'package:l_english/features/auth/ui/register_confirm_screen.dart';
import 'package:provider/provider.dart';

void main() {
  late MockAuthApi api;
  late InMemoryTokenStore tokenStore;
  late AuthController controller;

  setUp(() {
    api = MockAuthApi(latency: Duration.zero);
    tokenStore = InMemoryTokenStore();
    controller = AuthController(api: api, tokenStore: tokenStore);
  });

  Future<bool> requestCode({
    String username = 'newuser',
    String email = 'newuser@example.com',
    String password = '12345678',
  }) => controller.register(
    name: 'Nguyễn Văn A',
    username: username,
    email: email,
    password: password,
  );

  group('MockAuthApi — đăng ký 2 bước', () {
    test(
      'bước 1 chưa tạo tài khoản, bước 2 mới tạo và đăng nhập được',
      () async {
        expect(await requestCode(), isTrue);
        expect(api.displayNameOf('newuser'), isNull);
        expect(await controller.login('newuser', '12345678'), isFalse);

        expect(
          await controller.confirmRegistration(
            'newuser@example.com',
            MockAuthApi.debugRegistrationCode,
          ),
          isTrue,
        );
        expect(api.displayNameOf('newuser'), 'Nguyễn Văn A');
        expect(await controller.login('newuser', '12345678'), isTrue);
      },
    );

    test('email được chuẩn hoá chữ thường khi tra bản nháp', () async {
      await requestCode(email: 'NewUser@Example.com');
      expect(
        await controller.confirmRegistration(
          'newuser@example.com',
          MockAuthApi.debugRegistrationCode,
        ),
        isTrue,
      );
    });

    test('xác thực khi không có bản nháp trả 400 chung một câu', () async {
      expect(
        await controller.confirmRegistration(
          'khongco@example.com',
          MockAuthApi.debugRegistrationCode,
        ),
        isFalse,
      );
      expect(controller.errorMessage, 'Mã xác thực không đúng hoặc đã hết hạn');
    });

    test('mã sai định dạng bị từ chối trước khi tra bản nháp', () async {
      await requestCode();
      expect(
        await controller.confirmRegistration('newuser@example.com', '12345'),
        isFalse,
      );
      expect(controller.errorMessage, 'Mã xác thực phải gồm 6 chữ số');
    });

    test(
      'sai 5 lần thì bản nháp bị huỷ, mã đúng sau đó cũng vô hiệu',
      () async {
        await requestCode();
        for (
          var attempt = 0;
          attempt < MockAuthApi.registrationMaxAttempts;
          attempt++
        ) {
          await controller.confirmRegistration('newuser@example.com', '000000');
        }

        expect(
          await controller.confirmRegistration(
            'newuser@example.com',
            MockAuthApi.debugRegistrationCode,
          ),
          isFalse,
        );
        expect(await controller.login('newuser', '12345678'), isFalse);
      },
    );

    test(
      'gửi lại mã reset số lần sai: chưa đủ 5 thì bản nháp còn sống',
      () async {
        await requestCode();
        for (var attempt = 0; attempt < 4; attempt++) {
          await controller.confirmRegistration('newuser@example.com', '000000');
        }

        // Gửi lại mã = gọi lại register: bản nháp được refresh, attempts về 0.
        expect(await requestCode(), isTrue);

        for (var attempt = 0; attempt < 4; attempt++) {
          await controller.confirmRegistration('newuser@example.com', '000000');
        }
        expect(
          await controller.confirmRegistration(
            'newuser@example.com',
            MockAuthApi.debugRegistrationCode,
          ),
          isTrue,
        );
      },
    );

    test('username đang bị bản nháp của email khác giữ thì trả 409', () async {
      expect(await requestCode(email: 'mot@example.com'), isTrue);

      final conflict = await requestCode(email: 'hai@example.com');
      expect(conflict, isFalse);
      expect(controller.errorMessage, 'Tên đăng nhập đã tồn tại');
    });

    test('email không hợp lệ bị từ chối', () async {
      final success = await controller.register(
        name: 'Nguyễn Văn A',
        username: 'newuser',
        email: 'khong-phai-email',
        password: '12345678',
      );
      expect(success, isFalse);
      expect(controller.errorMessage, 'Email không hợp lệ');
    });

    test('username có ký tự lạ bị từ chối', () async {
      final success = await requestCode(username: 'new user!');
      expect(success, isFalse);
      expect(
        controller.errorMessage,
        'Tên đăng nhập chỉ được chứa chữ cái, số, dấu chấm và gạch dưới',
      );
    });

    test('mật khẩu hơn 72 byte UTF-8 bị từ chối như @MaxUtf8Bytes', () async {
      final success = await requestCode(password: 'ă' * 40);
      expect(success, isFalse);
      expect(controller.errorMessage, 'Mật khẩu không được vượt quá 72 byte');
    });

    test(
      'sai mã một lần chưa xoá bản nháp: mã đúng vẫn tạo được tài khoản',
      () async {
        await requestCode();
        await controller.confirmRegistration('newuser@example.com', '000000');
        expect(
          await controller.confirmRegistration(
            'newuser@example.com',
            MockAuthApi.debugRegistrationCode,
          ),
          isTrue,
        );
      },
    );
  });

  group('Widget — luồng đăng ký 2 bước', () {
    Finder fieldFor(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(TextField))
        .last;

    Future<void> pumpAuthScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>(
          create: (_) => controller,
          child: const MaterialApp(home: AuthScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();
    }

    Future<void> fillRegisterForm(WidgetTester tester) async {
      await tester.enterText(fieldFor('Tên hiển thị'), 'Nguyễn Văn A');
      await tester.enterText(fieldFor('Tên đăng nhập'), 'newuser');
      await tester.enterText(fieldFor('Email'), 'newuser@example.com');
      await tester.enterText(fieldFor('Mật khẩu (≥ 8 ký tự)'), '12345678');
      await tester.enterText(fieldFor('Xác nhận lại mật khẩu'), '12345678');
    }

    /// Nút nằm cuối form trong SingleChildScrollView nên phải cuộn tới trước
    /// khi tap, nếu không hit-test trượt vì nút ở ngoài viewport 600px.
    Future<void> tapCreateAccount(WidgetTester tester) async {
      final button = find.widgetWithText(ElevatedButton, 'Tạo tài khoản');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
    }

    Future<void> tapConfirm(WidgetTester tester) async {
      final button = find.widgetWithText(
        ElevatedButton,
        'Xác thực & tạo tài khoản',
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
    }

    testWidgets(
      'gửi form → xác thực mã đúng → về tab Đăng nhập với banner xanh',
      (tester) async {
        await pumpAuthScreen(tester);
        await fillRegisterForm(tester);

        await tapCreateAccount(tester);
        await tester.pumpAndSettle();

        expect(find.byType(RegisterConfirmScreen), findsOneWidget);
        expect(find.text('newuser@example.com'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Mã xác thực'),
          MockAuthApi.debugRegistrationCode,
        );
        await tapConfirm(tester);
        await tester.pumpAndSettle();

        expect(find.byType(RegisterConfirmScreen), findsNothing);
        expect(find.text('Tạo tài khoản thành công'), findsOneWidget);

        // Username đã điền sẵn, chỉ cần mật khẩu để đăng nhập.
        await tester.enterText(fieldFor('Mật khẩu'), '12345678');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
        await tester.pumpAndSettle();
        expect(tokenStore.hasSession, isTrue);
      },
    );

    testWidgets('mã sai hiện banner lỗi và vẫn ở màn xác thực', (tester) async {
      await pumpAuthScreen(tester);
      await fillRegisterForm(tester);

      await tapCreateAccount(tester);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Mã xác thực'),
        '000000',
      );
      await tapConfirm(tester);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterConfirmScreen), findsOneWidget);
      expect(
        find.text('Mã xác thực không đúng hoặc đã hết hạn'),
        findsOneWidget,
      );
      expect(find.text('Tạo tài khoản thành công'), findsNothing);
    });

    testWidgets('form đăng ký không tràn layout và có ô Email', (tester) async {
      await pumpAuthScreen(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Gửi mã xác thực'), findsNothing);
    });
  });
}
