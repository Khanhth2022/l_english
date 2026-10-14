import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/features/phrases/data/mock_phrase_api.dart';
import 'package:l_english/features/phrases/data/phrase_api.dart';
import 'package:l_english/features/phrases/state/phrase_form_controller.dart';
import 'package:l_english/features/phrases/state/phrase_list_controller.dart';
import 'package:l_english/features/phrases/ui/phrase_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phrase Module (act-10, act-11, act-12, act-13)', () {
    late MockPhraseApi api;
    late PhraseListController listController;
    late PhraseFormController formController;

    setUp(() {
      api = MockPhraseApi(latency: Duration.zero);
      listController = PhraseListController(api);
      formController = PhraseFormController(api);
    });

    test('Tải danh sách đoạn văn ban đầu có sẵn các bài mẫu', () async {
      await listController.load();
      expect(listController.phrases.length, greaterThanOrEqualTo(3));
      expect(listController.averageScore, inInclusiveRange(0, 10));
    });

    test('Chấm điểm câu có lỗi ngữ pháp phát hiện đúng lỗi và điểm số', () async {
      formController.setText('I has went to school yesterday.');
      final result = await formController.submitForGrading();

      expect(result, isNotNull);
      expect(result!.score, lessThan(10));
      expect(result.correctedText, contains('I went'));
      expect(result.errors.length, 1);
      expect(result.errors.first.incorrect, contains('has went'));
      expect(result.errors.first.explanation, isNotEmpty);
    });

    test('Chấm điểm câu đúng hoàn toàn được điểm 10', () async {
      formController.setText('English has become an essential language in the modern globalization era.');
      final result = await formController.submitForGrading();

      expect(result, isNotNull);
      expect(result!.score, 10);
      expect(result.errors, isEmpty);
    });

    test('Nhập câu dưới 10 ký tự bị từ chối 400', () async {
      formController.setText('Hi there');
      final result = await formController.submitForGrading();

      expect(result, isNull);
      expect(formController.errorMessage, contains('10 ký tự'));
    });

    test('Xóa đoạn văn thành công cập nhật danh sách', () async {
      await listController.load();
      final initialCount = listController.phrases.length;
      final toDelete = listController.phrases.first;

      final error = await listController.deletePhrase(toDelete);
      expect(error, isNull);
      expect(listController.phrases.length, initialCount - 1);
    });

    test('Gọi dispose() trước hoặc trong khi chấm điểm không văng exception', () async {
      formController.setText('This is a valid sentence to test dispose safely.');
      formController.dispose();
      expect(formController.isDisposed, isTrue);

      // notifyListeners() sau dispose phải được bỏ qua một cách an toàn mà không throw
      expect(() => formController.notifyListeners(), returnsNormally);
      final result = await formController.submitForGrading();
      expect(result, isNotNull);
    });

    testWidgets('PhraseFormScreen hiển thị nút Quét ảnh (OCR) theo act-17', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<PhraseApi>.value(
            value: api,
            child: const PhraseFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chấm đoạn văn bằng AI'), findsOneWidget);
      expect(find.text('Quét ảnh (OCR)'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_rounded), findsWidgets);
    });

    testWidgets('PhraseFormScreen hỗ trợ initialText từ tính năng quét OCR hoặc bôi đen', (tester) async {
      const scannedText = 'Although online learning provides great flexibility, students face difficulties.';
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<PhraseApi>.value(
            value: api,
            child: const PhraseFormScreen(initialText: scannedText),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(scannedText), findsOneWidget);
      expect(find.text('${scannedText.length} ký tự'), findsOneWidget);
    });
  });
}
