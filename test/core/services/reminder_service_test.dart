import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/services/reminder/reminder_service.dart';

void main() {
  group('ReminderService trên môi trường không phải Android', () {
    test('loadSettings trả null thay vì ném lỗi', () async {
      expect(await ReminderService.loadSettings(), isNull);
    });

    test('schedule và cancel trả false an toàn', () async {
      expect(await ReminderService.schedule(hour: 20, minute: 0), isFalse);
      expect(await ReminderService.cancel(), isFalse);
    });
  });
}
