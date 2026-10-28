import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Cấu hình lời nhắc ôn tập đang lưu trong bộ nhớ native.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
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

  static bool get _isAndroid {
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
      return ReminderSettings(
        enabled: map['enabled'] == true,
        hour: (map['hour'] as num?)?.toInt() ?? 20,
        minute: (map['minute'] as num?)?.toInt() ?? 0,
      );
    } catch (error) {
      debugPrint('ReminderService: không đọc được cấu hình ($error).');
      return null;
    }
  }

  /// Đặt lời nhắc hằng ngày; Android 13+ sẽ hỏi quyền thông báo.
  static Future<bool> schedule({required int hour, required int minute}) async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('scheduleReminder', {
        'hour': hour,
        'minute': minute,
      });
      return result ?? false;
    } catch (error) {
      debugPrint('ReminderService: không đặt được lời nhắc ($error).');
      return false;
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
