import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/services/widget/widget_service.dart';
import 'package:l_english/features/words/ui/word_list_screen.dart';

void main() {
  group('WidgetService & Home Screen Widget (act-15)', () {
    test('syncWidget chạy an toàn trên môi trường test mà không gây crash', () async {
      final result = await WidgetService.syncWidget(
        dueCount: 5,
        accessToken: 'mock_token',
        baseUrl: 'https://example.com',
      );
      // Trên test runner (môi trường non-Android), kết quả là false do Platform.isAndroid
      expect(result, isFalse);
    });

    test('getInitialRoute trả về null an toàn khi chạy trên môi trường test', () async {
      final route = await WidgetService.getInitialRoute();
      expect(route, isNull);
    });

    test('WordListScreen.selectedTabNotifier thông báo đúng khi chuyển tab Ôn tập', () {
      WordListScreen.selectedTabNotifier.value = 0;
      expect(WordListScreen.selectedTabNotifier.value, 0);

      int notifiedValue = -1;
      void listener() {
        notifiedValue = WordListScreen.selectedTabNotifier.value;
      }

      WordListScreen.selectedTabNotifier.addListener(listener);

      // Mô phỏng sự kiện mở từ Widget -> chọn tab 1 (Ôn tập)
      WordListScreen.selectedTabNotifier.value = 1;
      expect(notifiedValue, 1);

      WordListScreen.selectedTabNotifier.removeListener(listener);
    });
  });
}
