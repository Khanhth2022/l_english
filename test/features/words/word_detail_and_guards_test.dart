import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/theme/app_theme.dart';
import 'package:l_english/features/android_tools/ui/android_features_screen.dart';
import 'package:l_english/features/words/data/mock_word_api.dart';
import 'package:l_english/features/words/data/models/word.dart';
import 'package:l_english/features/words/data/word_api.dart';
import 'package:l_english/features/words/ui/topic_words_screen.dart';
import 'package:l_english/features/words/ui/widgets/word_detail_sheet.dart';
import 'package:l_english/features/words/ui/word_form_screen.dart';
import 'package:l_english/features/words/ui/word_list_screen.dart';
import 'package:provider/provider.dart';

/// Màn hình giả để mở form Thêm/Sửa từ bằng một lần push thật.
class _Host extends StatelessWidget {
  const _Host({this.existing});

  final Word? existing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => WordFormScreen(existing: existing),
              ),
            ),
            child: const Text('Mở form'),
          ),
        ),
      ),
    );
  }
}

Future<void> pumpScreen(WidgetTester tester, Widget child, WordApi? api) async {
  tester.view.physicalSize = const Size(1200, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Provider<WordApi>.value(
      value: api ?? MockWordApi(latency: Duration.zero),
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ACT-5: xem từ ở chế độ chỉ đọc', () {
    testWidgets('chạm thẻ từ mở sheet chi tiết thay vì form sửa', (
      tester,
    ) async {
      await pumpScreen(tester, const WordListScreen(), null);

      await tester.tap(find.text('achieve'));
      await tester.pumpAndSettle();

      expect(find.byType(WordDetailSheet), findsOneWidget);
      expect(find.byType(WordFormScreen), findsNothing);
      expect(find.text('Sửa từ'), findsNothing);
      expect(find.textContaining('chế độ chỉ xem'), findsOneWidget);
    });

    testWidgets('nhãn đến hạn ôn tập có màu đỏ', (tester) async {
      await pumpScreen(tester, const WordListScreen(), null);

      final label = tester.widget<Text>(find.text('quá hạn 1 ngày'));
      expect(label.style?.color, AppTheme.errorRed);
    });
  });

  group('ACT-19: xác nhận ôn tập', () {
    testWidgets('nút ôn tập dưới không hiện khi chưa tick từ nào', (
      tester,
    ) async {
      await pumpScreen(tester, const WordListScreen(), null);
      await tester.tap(find.text('Ôn tập (2)'));
      await tester.pumpAndSettle();

      // Banner phía trên vẫn là nơi bắt đầu phiên ôn tập.
      expect(find.text('Bắt đầu'), findsOneWidget);
      // Không còn nút ôn tập trùng lặp ở dưới, và nút đánh dấu cũng chưa hiện.
      expect(
        find.widgetWithText(FloatingActionButton, 'Ôn tập (2)'),
        findsNothing,
      );
      expect(find.textContaining('Đánh dấu là đã ôn'), findsNothing);

      await tester.tap(find.text('achieve'));
      await tester.pumpAndSettle();

      expect(find.text('Đánh dấu là đã ôn (1)'), findsOneWidget);
      // Banner không bị thay thế: hai nút vẫn khác chức năng.
      expect(find.text('Bắt đầu'), findsOneWidget);
    });
  });

  group('ACT-20: thêm từ theo chủ đề', () {
    testWidgets('nút nằm trong form thêm từ và vẫn mở được màn hình AI', (
      tester,
    ) async {
      await pumpScreen(tester, const WordListScreen(), null);

      // Icon ở AppBar sổ từ đã được bỏ.
      expect(find.byTooltip('Thêm từ theo chủ đề (AI)'), findsNothing);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Thêm từ'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm từ theo chủ đề với AI'), findsOneWidget);

      await tester.tap(find.text('Thêm từ theo chủ đề với AI'));
      await tester.pumpAndSettle();

      expect(find.byType(TopicWordsScreen), findsOneWidget);
    });

    testWidgets('tab Tiện ích giới thiệu chức năng', (tester) async {
      await pumpScreen(tester, const AndroidFeaturesScreen(), null);

      expect(find.text('Thêm từ theo chủ đề với AI'), findsOneWidget);
      expect(find.textContaining('Cách dùng:'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Thêm từ theo chủ đề'),
        findsOneWidget,
      );
    });
  });

  group('ACT-6: xác nhận khi AI thay thế nghĩa đã nhập', () {
    testWidgets('nút huỷ trong hộp thoại là "Thoát"', (tester) async {
      await pumpScreen(tester, const _Host(), null);
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'resilient');
      await tester.enterText(find.byType(TextField).at(1), 'kiên cường');
      await tester.tap(find.text('Gợi ý nghĩa bằng AI'));
      await tester.pumpAndSettle();

      expect(find.text('Thay thế nghĩa đã nhập?'), findsOneWidget);
      expect(find.text('Giữ nguyên'), findsNothing);
      expect(find.text('Thoát'), findsOneWidget);

      await tester.tap(find.text('Thoát'));
      await tester.pumpAndSettle();

      expect(find.text('Thay thế nghĩa đã nhập?'), findsNothing);
      expect(find.textContaining('Đã điền'), findsNothing);
    });

    testWidgets('back sau khi nhập từ phải hỏi xác nhận thoát', (tester) async {
      await pumpScreen(tester, const _Host(), null);
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'resilient');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Thoát mà không lưu?'), findsOneWidget);
      expect(
        find.textContaining('Bạn đã nhập thông tin cho từ mới'),
        findsOneWidget,
      );

      // Ở lại: form vẫn còn nguyên dữ liệu.
      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm vào sổ từ'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thoát'));
      await tester.pumpAndSettle();

      expect(find.text('Mở form'), findsOneWidget);
    });

    testWidgets('form trống thì back không hỏi gì', (tester) async {
      await pumpScreen(tester, const _Host(), null);
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Thoát mà không lưu?'), findsNothing);
      expect(find.text('Mở form'), findsOneWidget);
    });
  });

  group('ACT-7: sửa từ', () {
    Future<Word> loadAchieve(WordApi api) async {
      final words = await api.fetchWords();
      return words.firstWhere((word) => word.english == 'achieve');
    }

    testWidgets('không thay đổi dữ liệu thì AI không hỏi xác nhận', (
      tester,
    ) async {
      final api = MockWordApi(latency: Duration.zero);
      final existing = await loadAchieve(api);

      await pumpScreen(tester, _Host(existing: existing), api);
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gợi ý nghĩa bằng AI'));
      await tester.pumpAndSettle();

      expect(find.text('Thay thế nghĩa đã nhập?'), findsNothing);
      expect(find.textContaining('Đã điền'), findsOneWidget);
    });

    testWidgets('không sửa gì thì back thoát luôn, sửa rồi mới hỏi', (
      tester,
    ) async {
      final api = MockWordApi(latency: Duration.zero);
      final existing = await loadAchieve(api);

      await pumpScreen(tester, _Host(existing: existing), api);
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Thoát mà không lưu?'), findsNothing);
      expect(find.text('Mở form'), findsOneWidget);

      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'achieved');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Thoát mà không lưu?'), findsOneWidget);
      expect(
        find.textContaining('Bạn đã sửa thông tin của từ này'),
        findsOneWidget,
      );

      await tester.tap(find.text('Thoát'));
      await tester.pumpAndSettle();
      expect(find.text('Mở form'), findsOneWidget);
    });

    testWidgets('sửa dữ liệu rồi nhờ AI vẫn hỏi xác nhận với nút "Thoát"', (
      tester,
    ) async {
      final api = MockWordApi(latency: Duration.zero);
      final existing = await loadAchieve(api);

      await pumpScreen(tester, _Host(existing: existing), api);
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'đạt được');
      await tester.tap(find.text('Gợi ý nghĩa bằng AI'));
      await tester.pumpAndSettle();

      expect(find.text('Thay thế nghĩa đã nhập?'), findsOneWidget);
      expect(find.text('Thoát'), findsOneWidget);
    });
  });
}
