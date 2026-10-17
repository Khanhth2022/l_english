import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/auth/token_store.dart';
import 'package:l_english/core/config/app_config.dart';
import 'package:l_english/features/auth/data/mock_auth_api.dart';
import 'package:l_english/features/auth/state/auth_controller.dart';
import 'package:l_english/features/auth/ui/auth_screen.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildTestableAuthScreen({Dio? dio}) {
    final tokenStore = InMemoryTokenStore();
    final authApi = MockAuthApi();
    return MultiProvider(
      providers: [
        Provider<Dio?>.value(value: dio),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(api: authApi, tokenStore: tokenStore),
        ),
      ],
      child: const MaterialApp(
        home: AuthScreen(),
      ),
    );
  }

  testWidgets('mở hộp thoại Cấu hình Base URL và kiểm tra các thành phần giao diện', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://old.com'));
    await tester.pumpWidget(buildTestableAuthScreen(dio: dio));

    // Tìm và ấn nút cấu hình Base URL trên AppBar
    final tuneButton = find.byTooltip('Cấu hình Base URL');
    expect(tuneButton, findsOneWidget);
    await tester.tap(tuneButton);
    await tester.pumpAndSettle();

    // Hộp thoại xuất hiện
    expect(find.text('Cấu hình Base URL'), findsOneWidget);
    expect(find.text('Chọn nhanh (Presets):'), findsOneWidget);
    expect(find.text('Cloudflare Tunnel'), findsOneWidget);
    expect(find.text('Máy ảo (10.0.2.2)'), findsOneWidget);
    expect(find.text('Localhost (8080)'), findsOneWidget);
    expect(find.text('Kiểm tra kết nối tới máy chủ'), findsOneWidget);

    // Bấm nút preset Máy ảo (10.0.2.2)
    await tester.tap(find.text('Máy ảo (10.0.2.2)'));
    await tester.pumpAndSettle();

    // Ô nhập chuyển sang http://10.0.2.2:8080
    expect(find.text('http://10.0.2.2:8080'), findsOneWidget);

    // Bấm "Lưu & Áp dụng"
    await tester.tap(find.text('Lưu & Áp dụng'));
    await tester.pumpAndSettle();

    // Dialog đóng và Base URL được cập nhật
    expect(find.text('Cấu hình Base URL'), findsNothing);
    expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:8080');
    expect(dio.options.baseUrl, 'http://10.0.2.2:8080');
  });
}
