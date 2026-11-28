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

  /// §5.1 — đăng ký bước 1: gửi form, nhận câu "đã gửi mã".
  ///
  /// Không lưu token và không có phiên: tài khoản chưa tồn tại cho tới khi
  /// [confirmRegistration] nhận đúng mã trong email.
  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      successMessage = await api.register(
        name: name,
        username: username,
        email: email,
        password: password,
      );
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

  /// §5.1 — đăng ký bước 2: xác thực mã và tạo tài khoản.
  ///
  /// Thành công không cấp token (`AuthResponse` được cố ý bỏ qua), nên người
  /// dùng quay lại màn Đăng nhập và đăng nhập bằng username.
  Future<bool> confirmRegistration(String email, String code) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      successMessage = await api.confirmRegistration(email, code);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('AuthController: xác thực đăng ký thất bại ($e).');
      errorMessage = 'Xác thực không thành công. Vui lòng thử lại.';
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
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
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

  /// §2.6 — bước 1 của quên mật khẩu: xin mã xác thực qua email.
  ///
  /// Không đụng tới token hiện tại: người dùng đang ở màn đăng nhập nên chưa
  /// có phiên nào để thu hồi.
  Future<bool> forgotPassword(String email) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      successMessage = await api.forgotPassword(email);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('AuthController: yêu cầu mã đặt lại thất bại ($e).');
      errorMessage = 'Không gửi được yêu cầu. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// §2.6 — bước 2: đặt lại mật khẩu bằng mã đã nhận.
  ///
  /// Backend không cấp token mới và đã thu hồi mọi refresh token, nên client
  /// chỉ báo thành công rồi đưa người dùng về màn đăng nhập.
  Future<bool> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      successMessage = await api.resetPassword(email, code, newPassword);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('AuthController: đặt lại mật khẩu thất bại ($e).');
      errorMessage = 'Đặt lại mật khẩu không thành công. Vui lòng thử lại.';
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
