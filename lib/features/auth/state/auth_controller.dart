import 'package:flutter/foundation.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/widget/widget_service.dart';
import '../../../core/state/safe_change_notifier.dart';
import '../data/auth_api.dart';

class AuthController extends ChangeNotifier with SafeChangeNotifier {
  AuthController({required this.api, required this.tokenStore});

  final AuthApi api;
  final TokenStore tokenStore;

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  bool get isLoggedIn => tokenStore.hasSession;
  String? get currentUsername => tokenStore.currentUsername;

  Future<bool> login(String username, String password) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final response = await api.login(username, password);
      await tokenStore.save(
        TokenPair(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
        ),
        username: username.trim(),
      );
      WidgetService.syncWidget(
        accessToken: response.accessToken,
        baseUrl: AppConfig.apiBaseUrl,
      );
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('AuthController: đăng nhập thất bại ($e).');
      errorMessage = 'Đăng nhập không thành công. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// §5.1 — tạo tài khoản. `name` là tên hiển thị bắt buộc của backend.
  Future<bool> register(
    String username,
    String password, {
    required String name,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final message = await api.register(username, password, name: name);
      successMessage = message;
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('AuthController: đăng ký thất bại ($e).');
      errorMessage = 'Đăng ký không thành công. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// §2.5 — đổi mật khẩu của tài khoản đang đăng nhập.
  ///
  /// Không xoá phiên ở đây: access token hiện tại vẫn hợp lệ tới khi hết hạn,
  /// còn refresh token thì backend đã thu hồi nên lần gia hạn kế tiếp sẽ đưa
  /// người dùng về màn đăng nhập. Xoá token ngay sẽ đăng xuất người dùng giữa
  /// lúc họ vừa đổi mật khẩu thành công.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      successMessage = await api.changePassword(currentPassword, newPassword);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('AuthController: đổi mật khẩu thất bại ($e).');
      errorMessage = 'Đổi mật khẩu không thành công. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> logout() async {
    final tokens = tokenStore.tokens;
    if (tokens != null) {
      try {
        await api.logout(tokens.refreshToken);
      } catch (_) {}
    }
    await tokenStore.clear();
    WidgetService.clearWidgetSession();
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
