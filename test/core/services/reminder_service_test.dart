import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/services/reminder/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.lenglish.l_english/reminder');

  group('ReminderService trên môi trường không phải Android', () {
    test('loadSettings trả null thay vì ném lỗi', () async {
      expect(await ReminderService.loadSettings(), isNull);
    });

    test('schedule và cancel trả false an toàn', () async {
      expect(await ReminderService.schedule(hour: 20, minute: 0), isFalse);
      expect(await ReminderService.cancel(), isFalse);
    });
  });

  group('ReminderService — hợp đồng MethodChannel với native Android', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      ReminderService.debugTreatAsAndroid = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getReminderSettings') {
          return <String, Object?>{
            'enabled': true,
            'hour': 21,
            'minute': 5,
            'userName': 'Nam',
          };
        }
        return true;
      });
    });

    tearDown(() {
      ReminderService.debugTreatAsAndroid = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('đặt lại giờ lần hai vẫn gửi một lệnh scheduleReminder mới', () async {
      final first = await ReminderService.schedule(
        hour: 21,
        minute: 5,
        userName: 'Nam',
      );
      final second = await ReminderService.schedule(
        hour: 21,
        minute: 30,
        userName: 'Nam',
      );

      expect(first, isTrue);
      expect(second, isTrue);
      final schedules =
          calls.where((call) => call.method == 'scheduleReminder').toList();
      expect(schedules, hasLength(2));
      expect(schedules.first.arguments, <String, Object?>{
        'hour': 21,
        'minute': 5,
        'userName': 'Nam',
      });
      expect(schedules.last.arguments, <String, Object?>{
        'hour': 21,
        'minute': 30,
        'userName': 'Nam',
      });
    });

    test('loadSettings đọc đúng cấu hình native trả về', () async {
      final settings = await ReminderService.loadSettings();

      expect(settings, isNotNull);
      expect(settings!.enabled, isTrue);
      expect(settings.hour, 21);
      expect(settings.minute, 5);
      expect(settings.userName, 'Nam');
    });

    test('không gửi userName rỗng để native giữ tên đã lưu', () async {
      await ReminderService.schedule(hour: 7, minute: 0);

      final call =
          calls.singleWhere((item) => item.method == 'scheduleReminder');
      expect(call.arguments, <String, Object?>{'hour': 7, 'minute': 0});
    });
  });
}
