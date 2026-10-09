import 'package:flutter/foundation.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_api.dart';

class AuthController extends ChangeNotifier {
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
      isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      errorMessage = 'Đăng nhập không thành công ($e).';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> register(String username, String password) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final message = await api.register(username, password);
      successMessage = message;
      isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      errorMessage = 'Đăng ký không thành công ($e).';
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
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
