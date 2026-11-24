import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cấu hình lời nhắc ôn tập đang lưu trong bộ nhớ native.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    this.userName,
  });

  final bool enabled;
  final int hour;
  final int minute;

  /// Tên hiển thị đang được in vào thông báo nhắc ôn tập (null nếu chưa có).
  final String? userName;
}

/// Cầu nối tới AlarmManager/NotificationManager của Android.
///
/// Trên nền tảng khác (test, web, desktop) mọi thao tác trả về an toàn để
/// giao diện không crash.
class ReminderService {
  ReminderService._();

  static const MethodChannel _channel = MethodChannel(
    'com.lenglish.l_english/reminder',
  );

  /// Bật để test trên host (Windows/Linux) đi thẳng qua MethodChannel như trên
  /// Android; mặc định tắt nên hành vi thật không đổi.
  @visibleForTesting
  static bool debugTreatAsAndroid = false;

  static bool get _isAndroid {
    if (debugTreatAsAndroid) return true;
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static Future<ReminderSettings?> loadSettings() async {
    if (!_isAndroid) return null;
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'getReminderSettings',
      );
      if (map == null) return null;
      final name = (map['userName'] as String?)?.trim();
      return ReminderSettings(
        enabled: map['enabled'] == true,
        hour: (map['hour'] as num?)?.toInt() ?? 20,
        minute: (map['minute'] as num?)?.toInt() ?? 0,
        userName: (name == null || name.isEmpty) ? null : name,
      );
    } catch (error) {
      debugPrint('ReminderService: không đọc được cấu hình ($error).');
      return null;
    }
  }

  /// Đặt lời nhắc hằng ngày; Android 13+ sẽ hỏi quyền thông báo.
  ///
  /// [userName] là tên hiển thị in vào tiêu đề thông báo ("Chào Nam, đến giờ
  /// ôn từ vựng"). Bỏ trống thì giữ tên đã lưu trước đó.
  static Future<bool> schedule({
    required int hour,
    required int minute,
    String? userName,
  }) async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('scheduleReminder', {
        'hour': hour,
        'minute': minute,
        if (userName != null && userName.trim().isNotEmpty)
          'userName': userName.trim(),
      });
      return result ?? false;
    } catch (error) {
      debugPrint('ReminderService: không đặt được lời nhắc ($error).');
      return false;
    }
  }

  /// Đổi tên hiển thị trong thông báo mà không đổi giờ nhắc.
  ///
  /// Gọi khi hồ sơ người dùng được tải hoặc sau khi đổi tên thành công.
  static Future<void> updateUserName(String? userName) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('setReminderUserName', {
        'userName': userName?.trim() ?? '',
      });
    } catch (error) {
      debugPrint('ReminderService: không đổi được tên trong thông báo ($error).');
    }
  }

  static Future<bool> cancel() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('cancelReminder');
      return result ?? false;
    } catch (error) {
      debugPrint('ReminderService: không huỷ được lời nhắc ($error).');
      return false;
    }
  }
}
