import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/auth/token_store.dart';
import 'package:l_english/core/config/app_config.dart';
import 'package:l_english/features/words/ui/connection_settings_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('ConnectionSettingsScreen', () {
    late InMemoryTokenStore tokenStore;
    late String originalBaseUrl;

    setUp(() {
      originalBaseUrl = AppConfig.apiBaseUrl;
      tokenStore = InMemoryTokenStore();
    });

    tearDown(() {
      AppConfig.setApiBaseUrl(originalBaseUrl);
    });

    Widget buildScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      return MultiProvider(
        providers: [
          Provider<Dio?>.value(value: null),
          ChangeNotifierProvider<TokenStore>.value(value: tokenStore),
        ],
        child: const MaterialApp(home: ConnectionSettingsScreen()),
      );
    }

    testWidgets('cho phép sửa Base URL và lưu kèm username', (tester) async {
      await tester.pumpWidget(buildScreen(tester));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Base URL'),
        'https://api.example.com/api/',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên đăng nhập'),
        'user2',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Access token'),
        'access-2',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Refresh token'),
        'refresh-2',
      );

      await tester.tap(find.text('Lưu phiên'));
      await tester.pumpAndSettle();

      expect(AppConfig.apiBaseUrl, 'https://api.example.com');
      expect(tokenStore.currentUsername, 'user2');
      expect(tokenStore.tokens?.accessToken, 'access-2');
      expect(tokenStore.tokens?.refreshToken, 'refresh-2');
    });

    testWidgets('chặn lưu khi chỉ nhập một trong hai token', (tester) async {
      await tester.pumpWidget(buildScreen(tester));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Access token'),
        'access-only',
      );

      await tester.tap(find.text('Lưu phiên'));
      await tester.pumpAndSettle();

      expect(tokenStore.tokens, isNull);
      expect(
        find.text('Cần nhập đủ cả access token và refresh token.'),
        findsOneWidget,
      );
    });
  });
}
