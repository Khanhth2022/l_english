import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/theme/app_theme.dart';
import 'package:l_english/features/words/data/mock_word_api.dart';
import 'package:l_english/features/words/data/models/enums.dart';
import 'package:l_english/features/words/data/models/word.dart';
import 'package:l_english/features/words/data/models/word_value.dart';
import 'package:l_english/features/words/data/word_api.dart';
import 'package:l_english/features/words/state/word_list_controller.dart';
import 'package:l_english/features/words/ui/review_quiz_screen.dart';
import 'package:l_english/features/words/ui/word_form_screen.dart';
import 'package:l_english/features/words/ui/word_list_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('ReviewQuizScreen (ACT-15, ACT-19)', () {
    final sampleDueWord = Word(
      id: 101,
      english: 'resilient',
      level: Level.b2,
      values: const [
        WordValue(
          id: 1,
          vietnamese: 'kiên cường, mau phục hồi',
          pronunciation: '/rɪˈzɪl.jənt/',
          example: 'He is resilient in difficulties.',
          exampleTranslation: 'Anh ấy rất kiên cường trong nghịch cảnh.',
          partOfSpeech: PartOfSpeech.adjective,
        ),
      ],
    );

    testWidgets('hiển thị câu hỏi ôn tập với đầy đủ thông tin từ và 4 lựa chọn',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final mockApi = MockWordApi(latency: Duration.zero);
      final controller = WordListController(mockApi);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ReviewQuizScreen(
              words: [sampleDueWord],
              allWords: [sampleDueWord],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('resilient'), findsOneWidget);
      expect(find.text('/rɪˈzɪl.jənt/'), findsOneWidget);
      expect(find.text('B2'), findsOneWidget);
      expect(find.text('Tính từ'), findsOneWidget);
      expect(find.text('kiên cường, mau phục hồi'), findsOneWidget);

      // Bấm vào đáp án đúng
      await tester.tap(find.text('kiên cường, mau phục hồi'));
      await tester.pumpAndSettle();

      expect(find.text('Chính xác!'), findsOneWidget);
      expect(find.text('1 đúng'), findsOneWidget);

      // Chuyển sang màn kết quả
      await tester.tap(find.text('Xem kết quả'));
      await tester.pumpAndSettle();

      expect(find.text('Hoàn thành phiên ôn tập!'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Xác nhận & Cập nhật tiến độ'), findsOneWidget);
    });

    testWidgets('chọn đáp án không nhớ / xem đáp án vẫn ghi nhận đã ôn từ',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final mockApi = MockWordApi(latency: Duration.zero);
      final controller = WordListController(mockApi);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ReviewQuizScreen(
              words: [sampleDueWord],
              allWords: [sampleDueWord],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm xem đáp án
      await tester.tap(find.text('Xem đáp án'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa chính xác!'), findsOneWidget);

      // Chuyển sang màn kết quả
      await tester.tap(find.text('Xem kết quả'));
      await tester.pumpAndSettle();

      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('1 từ'), findsOneWidget); // vẫn cập nhật SRS 1 từ
    });
  });

  group('WordFormScreen với bôi đen từ ngoài (ACT-16)', () {
    testWidgets('mở form với initialEnglish tự động điền sẵn từ vào ô',
        (tester) async {
      final api = MockWordApi(latency: Duration.zero);

      await tester.pumpWidget(
        Provider<WordApi>.value(
          value: api,
          child: const MaterialApp(
            home: WordFormScreen(initialEnglish: 'meticulous'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstTextField = find.byType(TextField).first;
      expect(tester.widget<TextField>(firstTextField).controller?.text, 'meticulous');
    });
  });

  group('WordListScreen Banner & Ôn tập (ACT-15)', () {
    testWidgets('tab Ôn tập hiển thị Banner Bắt đầu ôn tập khi có từ đến hạn',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final api = MockWordApi(latency: Duration.zero);
      final controller = WordListController(api);
      await controller.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: WordListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Chuyển sang tab Ôn tập
      await tester.tap(find.textContaining('Ôn tập ('));
      await tester.pumpAndSettle();

      expect(find.textContaining('từ cần ôn tập!'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsOneWidget);
    });
  });
}
