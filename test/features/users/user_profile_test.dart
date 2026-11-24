import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/auth/token_store.dart';
import 'package:l_english/core/network/api_exception.dart';
import 'package:l_english/features/auth/data/mock_auth_api.dart';
import 'package:l_english/features/auth/state/auth_controller.dart';
import 'package:l_english/features/auth/ui/profile_screen.dart';
import 'package:l_english/features/users/data/mock_user_api.dart';
import 'package:l_english/features/users/data/models/user_profile.dart';
import 'package:l_english/features/users/state/user_profile_controller.dart';
import 'package:provider/provider.dart';

Future<void> _pumpProfile(
  WidgetTester tester, {
  required TokenStore tokenStore,
  required MockUserApi userApi,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TokenStore>.value(value: tokenStore),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            api: MockAuthApi(latency: Duration.zero),
            tokenStore: tokenStore,
          ),
        ),
        ChangeNotifierProvider<UserProfileController>(
          create: (_) => UserProfileController(api: userApi),
        ),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('UserProfile.fromJson', () {
    test('đọc đủ id, username, name và trim tên', () {
      final profile = UserProfile.fromJson({
        'id': 7,
        'username': 'alice',
        'name': '  Nguyễn Văn A  ',
      });

      expect(profile.id, 7);
      expect(profile.username, 'alice');
      expect(profile.name, 'Nguyễn Văn A');
      expect(profile.displayName, 'Nguyễn Văn A');
    });

    test('name rỗng hoặc thiếu thì dùng username để hiển thị', () {
      final missing = UserProfile.fromJson({'id': 1, 'username': 'alice'});
      final blank = UserProfile.fromJson({
        'id': 1,
        'username': 'alice',
        'name': '   ',
      });

      expect(missing.name, isNull);
      expect(missing.displayName, 'alice');
      expect(blank.name, isNull);
      expect(blank.displayName, 'alice');
    });

    test('thiếu id/username thì báo dữ liệu không hợp lệ', () {
      expect(
        () => UserProfile.fromJson({'username': 'alice'}),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => UserProfile.fromJson({'id': 1}),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('MockUserApi (§ Hồ sơ người dùng)', () {
    test('trả hồ sơ của tài khoản đang đăng nhập', () async {
      final api = MockUserApi(
        latency: Duration.zero,
        usernameProvider: () => 'alice',
      );

      final profile = await api.fetchProfile();

      expect(profile.username, 'alice');
      expect(profile.name, isNull);
      expect(profile.displayName, 'alice');
    });

    test('đổi tên thì trim và lưu lại, đọc hồ sơ thấy tên mới', () async {
      final api = MockUserApi(
        latency: Duration.zero,
        usernameProvider: () => 'alice',
      );

      final updated = await api.updateName('  Nguyễn Văn A  ');
      expect(updated.name, 'Nguyễn Văn A');

      final reloaded = await api.fetchProfile();
      expect(reloaded.name, 'Nguyễn Văn A');
      expect(reloaded.username, 'alice');
    });

    test('tên đã lưu lúc đăng ký hiện ra trong hồ sơ (nameProvider)', () async {
      final authApi = MockAuthApi(latency: Duration.zero);
      await authApi.register('bob', '12345678', name: 'Bob Lê');

      final userApi = MockUserApi(
        latency: Duration.zero,
        usernameProvider: () => 'bob',
        nameProvider: authApi.displayNameOf,
      );

      final profile = await userApi.fetchProfile();
      expect(profile.displayName, 'Bob Lê');
    });

    test('tên rỗng bị từ chối', () async {
      final api = MockUserApi(latency: Duration.zero);

      await expectLater(
        api.updateName('   '),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'Tên không được để trống',
              ),
        ),
      );
    });

    test('tên dài hơn 100 ký tự bị từ chối', () async {
      final api = MockUserApi(latency: Duration.zero);

      await expectLater(
        api.updateName('a' * 101),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });

  group('UserProfileController', () {
    test('load() nạp hồ sơ và tắt isLoading', () async {
      final controller = UserProfileController(
        api: MockUserApi(
          latency: Duration.zero,
          usernameProvider: () => 'alice',
        ),
      );

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.profile?.username, 'alice');
      expect(controller.displayName, 'alice');
      expect(controller.errorMessage, isNull);
    });

    test('updateName() thành công cập nhật hồ sơ và successMessage', () async {
      final controller = UserProfileController(
        api: MockUserApi(
          latency: Duration.zero,
          usernameProvider: () => 'alice',
        ),
      );
      await controller.load();

      final ok = await controller.updateName('Nguyễn Văn A');

      expect(ok, isTrue);
      expect(controller.profile?.name, 'Nguyễn Văn A');
      expect(controller.displayName, 'Nguyễn Văn A');
      expect(controller.successMessage, 'Cập nhật tên thành công');
    });

    test('updateName() thất bại giữ nguyên tên cũ và đặt errorMessage', () async {
      final controller = UserProfileController(
        api: MockUserApi(
          latency: Duration.zero,
          usernameProvider: () => 'alice',
        ),
      );
      await controller.load();

      final ok = await controller.updateName('   ');

      expect(ok, isFalse);
      expect(controller.profile?.name, isNull);
      expect(controller.errorMessage, 'Tên không được để trống');
    });
  });

  group('ProfileScreen', () {
    testWidgets('hiển thị username khi chưa có tên hiển thị', (tester) async {
      final tokenStore = InMemoryTokenStore();
      await tokenStore.save(
        const TokenPair(accessToken: 'a', refreshToken: 'r'),
        username: 'alice',
      );

      await _pumpProfile(
        tester,
        tokenStore: tokenStore,
        userApi: MockUserApi(
          latency: Duration.zero,
          usernameProvider: () => tokenStore.currentUsername,
        ),
      );

      expect(find.text('@alice'), findsOneWidget);
      expect(find.text('Chưa đặt tên — đang dùng tên đăng nhập'), findsOneWidget);
    });

    testWidgets('đổi tên hiển thị qua hộp thoại', (tester) async {
      final tokenStore = InMemoryTokenStore();
      await tokenStore.save(
        const TokenPair(accessToken: 'a', refreshToken: 'r'),
        username: 'alice',
      );

      await _pumpProfile(
        tester,
        tokenStore: tokenStore,
        userApi: MockUserApi(
          latency: Duration.zero,
          usernameProvider: () => tokenStore.currentUsername,
        ),
      );

      await tester.tap(find.text('Đổi tên hiển thị'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Nguyễn Văn A');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Nguyễn Văn A'), findsWidgets);
      expect(find.text('Cập nhật tên thành công'), findsOneWidget);
    });

    testWidgets('chặn lưu khi tên để trống', (tester) async {
      final tokenStore = InMemoryTokenStore();
      await tokenStore.save(
        const TokenPair(accessToken: 'a', refreshToken: 'r'),
        username: 'alice',
      );

      await _pumpProfile(
        tester,
        tokenStore: tokenStore,
        userApi: MockUserApi(
          latency: Duration.zero,
          usernameProvider: () => tokenStore.currentUsername,
        ),
      );

      await tester.tap(find.text('Đổi tên hiển thị'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('Tên hiển thị không được để trống.'), findsOneWidget);
    });
  });
}
