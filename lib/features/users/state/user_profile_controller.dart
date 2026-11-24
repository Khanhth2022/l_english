import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/safe_change_notifier.dart';
import '../data/models/user_profile.dart';
import '../data/user_api.dart';

/// Trạng thái hồ sơ người dùng: tên hiển thị hiện tại và thao tác đổi tên.
class UserProfileController extends ChangeNotifier with SafeChangeNotifier {
  UserProfileController({required this.api});

  final UserApi api;

  UserProfile? profile;
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  /// Tên hiển thị đang dùng; `null` khi chưa tải xong hồ sơ.
  String? get displayName => profile?.displayName;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await api.fetchProfile();
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('UserProfileController: tải hồ sơ thất bại ($e).');
      errorMessage = 'Không tải được hồ sơ người dùng.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Đổi tên hiển thị. Trả `true` khi backend đã lưu; lỗi nằm ở
  /// [errorMessage] để màn hình hiển thị nguyên văn thông báo của máy chủ.
  Future<bool> updateName(String name) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      profile = await api.updateName(name);
      successMessage = 'Cập nhật tên thành công';
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (e) {
      debugPrint('UserProfileController: đổi tên thất bại ($e).');
      errorMessage = 'Đổi tên không thành công. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    return false;
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
