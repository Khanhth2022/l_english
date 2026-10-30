import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service quản lý giao tiếp và đồng bộ dữ liệu với Widget màn hình chính Android (act-15)
/// và xử lý bôi đen văn bản từ ứng dụng bên ngoài (act-16).
class WidgetService {
  WidgetService._();

  static const MethodChannel _channel =
      MethodChannel('com.lenglish.l_english/widget');

  static final List<void Function(String route)> _routeListeners = [];
  static final List<void Function(String text)> _processTextListeners = [];
  static bool _handlerInitialized = false;

  static void _ensureHandler() {
    if (_handlerInitialized || kIsWeb) return;
    _handlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNavigateRoute') {
        final route = call.arguments?.toString();
        if (route != null && route.isNotEmpty) {
          for (final listener in List.of(_routeListeners)) {
            listener(route);
          }
        }
      } else if (call.method == 'onProcessText') {
        final text = call.arguments?.toString();
        if (text != null && text.isNotEmpty) {
          for (final listener in List.of(_processTextListeners)) {
            listener(text);
          }
        }
      }
    });
  }

  /// Đồng bộ số từ cần ôn, access token và base URL sang SharedPreferences của Android.
  static Future<bool> syncWidget({
    int? dueCount,
    String? accessToken,
    String? baseUrl,
  }) async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
    } catch (_) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('updateWidgetData', {
        'dueCount': dueCount,
        'accessToken': accessToken,
        'baseUrl': baseUrl,
      });
      return result ?? true;
    } catch (e) {
      debugPrint('WidgetService: Không thể đồng bộ Widget Android: $e');
      return false;
    }
  }

  /// Xoá phiên của Widget (token + số từ) khi đăng xuất.
  /// Truyền chuỗi rỗng thay vì `null` để native thực sự ghi đè token cũ.
  static Future<bool> clearWidgetSession() =>
      syncWidget(accessToken: '', dueCount: 0);

  /// Lấy route điều hướng nếu app được kích hoạt khi bấm vào Widget màn hình chính.
  static Future<String?> getInitialRoute() async {
    if (kIsWeb) return null;
    try {
      if (!Platform.isAndroid) return null;
    } catch (_) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('getInitialRoute');
    } catch (_) {
      return null;
    }
  }

  /// Lấy văn bản được bôi đen từ ứng dụng bên ngoài khi khởi động (ACT-16).
  static Future<String?> getInitialProcessText() async {
    if (kIsWeb) return null;
    try {
      if (!Platform.isAndroid) return null;
    } catch (_) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('getInitialProcessText');
    } catch (_) {
      return null;
    }
  }

  /// Lắng nghe sự kiện người dùng bấm vào Widget khi ứng dụng đang chạy ở nền.
  static void listenForRoute(void Function(String route) onRoute) {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid) return;
    } catch (_) {
      return;
    }

    _ensureHandler();
    if (!_routeListeners.contains(onRoute)) {
      _routeListeners.add(onRoute);
    }
  }

  /// Lắng nghe sự kiện bôi đen từ ứng dụng ngoài khi app đang chạy nền (ACT-16).
  static void listenForProcessText(void Function(String text) onProcessText) {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid) return;
    } catch (_) {
      return;
    }

    _ensureHandler();
    if (!_processTextListeners.contains(onProcessText)) {
      _processTextListeners.add(onProcessText);
    }
  }

  /// Yêu cầu ghim Widget ra màn hình chính Android (hệ thống tự hiện hộp thoại xác nhận).
  static Future<bool> pinWidget() async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
    } catch (_) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('pinWidget');
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetService: Không thể yêu cầu ghim Widget: $e');
      return false;
    }
  }
}
