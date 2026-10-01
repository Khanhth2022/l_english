import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/features/words/data/mock_word_api.dart';
import 'package:l_english/features/words/data/models/word.dart';
import 'package:l_english/features/words/data/word_api.dart';
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
  // Màn hình form dài hơn màn hình mặc định 800x600 của test, mà ListView chỉ
  // dựng những ô trong tầm nhìn — dùng viewport cao để mọi ô đều được dựng.
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
  group('WordListScreen', () {
    testWidgets('hiển thị các từ đã tải và số từ đến hạn', (tester) async {
      await pumpScreen(tester, const WordListScreen(), null);

      expect(find.text('Sổ từ của tôi'), findsOneWidget);
      expect(find.text('achieve'), findsOneWidget);
      expect(find.text('curious'), findsOneWidget);
      expect(find.text('diligent'), findsOneWidget);
      // achieve quá hạn + curious là từ mới.
      expect(find.text('Ôn tập (2)'), findsOneWidget);
      expect(find.text('• đạt được, giành được'), findsOneWidget);
    });

    testWidgets('tab Ôn tập lọc theo next_review và xác nhận được ôn tập', (
      tester,
    ) async {
      await pumpScreen(tester, const WordListScreen(), null);

      await tester.tap(find.text('Ôn tập (2)'));
      await tester.pumpAndSettle();

      expect(find.text('achieve'), findsOneWidget);
      expect(find.text('curious'), findsOneWidget);
      expect(find.text('benefit'), findsNothing);
      expect(find.text('diligent'), findsNothing);

      await tester.tap(find.text('achieve'));
      await tester.tap(find.text('curious'));
      await tester.pumpAndSettle();

      expect(find.text('Đã ôn 2 từ'), findsOneWidget);

      await tester.tap(find.text('Đã ôn 2 từ'));
      await tester.pumpAndSettle();

      expect(
        find.text('Đã ghi nhận ôn tập 2 từ, lịch ôn đã được giãn ra.'),
        findsOneWidget,
      );
      expect(find.text('Ôn tập (0)'), findsOneWidget);
      expect(find.text('Không có từ nào đến hạn ôn'), findsOneWidget);
    });

    testWidgets('tìm kiếm theo nghĩa tiếng Việt', (tester) async {
      await pumpScreen(tester, const WordListScreen(), null);

      await tester.enterText(find.byType(TextField).first, 'lợi ích');
      await tester.pumpAndSettle();

      expect(find.text('benefit'), findsOneWidget);
      expect(find.text('achieve'), findsNothing);
    });

    testWidgets('xoá từ qua menu thao tác', (tester) async {
      await pumpScreen(tester, const WordListScreen(), null);

      final card = find.ancestor(
        of: find.text('achieve'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: card, matching: find.byIcon(Icons.more_vert)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá từ'));
      await tester.pumpAndSettle();

      expect(find.text('Xoá từ "achieve"?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
      await tester.pumpAndSettle();

      expect(find.text('achieve'), findsNothing);
      expect(find.text('Đã xoá từ "achieve".'), findsOneWidget);
    });

    testWidgets('nút Thêm từ mở form thêm từ mới', (tester) async {
      await pumpScreen(tester, const WordListScreen(), null);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Thêm từ'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm vào sổ từ'), findsOneWidget);
      expect(find.text('Gợi ý nghĩa bằng AI'), findsOneWidget);
      expect(find.text('Nghĩa của từ'), findsOneWidget);
    });
  });

  group('WordFormScreen', () {
    testWidgets('gợi ý nghĩa bằng AI rồi lưu từ mới', (tester) async {
      final api = MockWordApi(latency: Duration.zero);
      await pumpScreen(tester, const _Host(), api);

      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'resilient');
      await tester.tap(find.text('Gợi ý nghĩa bằng AI'));
      await tester.pumpAndSettle();

      expect(find.text('Đã điền 2 nghĩa cho "resilient".'), findsOneWidget);
      expect(find.text('Nghĩa tiếng Việt *'), findsNWidgets(2), reason: 'AI trả về 2 nghĩa');

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm vào sổ từ'));
      await tester.pumpAndSettle();

      expect(find.text('Mở form'), findsOneWidget, reason: 'lưu xong thì quay lại');
      final words = await api.fetchWords();
      expect(words.any((word) => word.english == 'resilient'), isTrue);
    });

    testWidgets('form Sửa từ nạp sẵn dữ liệu cũ', (tester) async {
      final api = MockWordApi(latency: Duration.zero);
      final existing = (await api.fetchWords()).firstWhere(
        (word) => word.english == 'achieve',
      );

      await pumpScreen(tester, _Host(existing: existing), api);
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();

      expect(find.text('Sửa từ'), findsOneWidget);
      expect(find.text('Cập nhật từ'), findsOneWidget);

      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.first).controller?.text, 'achieve');
      expect(
        tester.widget<TextField>(fields.at(1)).controller?.text,
        'đạt được, giành được',
      );
    });
  });
}
