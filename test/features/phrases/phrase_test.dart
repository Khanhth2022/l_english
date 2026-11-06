import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/features/phrases/data/mock_phrase_api.dart';
import 'package:l_english/features/phrases/data/models/phrase_models.dart';
import 'package:l_english/features/phrases/data/phrase_api.dart';
import 'package:l_english/features/phrases/state/phrase_form_controller.dart';
import 'package:l_english/features/phrases/state/phrase_list_controller.dart';
import 'package:l_english/features/phrases/ui/phrase_form_screen.dart';
import 'package:l_english/features/phrases/ui/phrase_list_screen.dart';
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

    test('Để trống tiêu đề thì lưu với nhãn [Không có tiêu đề]', () async {
      formController.setText('This is a valid sentence without an explicit title.');
      final result = await formController.submitForGrading();

      expect(result, isNotNull);
      expect(result!.title, '[Không có tiêu đề]');
      expect(result.displayTitle, '[Không có tiêu đề]');
    });

    test('Tiêu đề người dùng nhập được lưu nguyên văn, tách khỏi nội dung chấm', () async {
      formController.titleController.text = 'Luyện viết IELTS';
      formController.setText('I has went to school yesterday.');
      final result = await formController.submitForGrading();

      expect(result, isNotNull);
      expect(result!.title, 'Luyện viết IELTS');
      // Tiêu đề chỉ để hiển thị: phần AI chấm vẫn là `text`, không dính tiêu đề.
      expect(result.text, 'I has went to school yesterday.');
      expect(result.correctedText, isNot(contains('Luyện viết IELTS')));
    });

    test('Tiêu đề dài quá 255 ký tự bị chặn trước khi gọi API', () async {
      formController.titleController.text = 'a' * 256;
      formController.setText('This is a valid sentence with a very long title.');

      final result = await formController.submitForGrading();

      expect(result, isNull);
      expect(formController.errorMessage, contains('255'));
    });

    test('Phrase.fromJson đọc được title; dữ liệu cũ thiếu title rơi về nhãn mặc định', () {
      final withTitle = Phrase.fromJson(const {
        'id': 7,
        'title': 'Thư xin việc',
        'text': 'I am writing to apply for the position.',
        'correctedText': 'I am writing to apply for the position.',
        'score': 10,
      });
      expect(withTitle.title, 'Thư xin việc');
      expect(withTitle.displayTitle, 'Thư xin việc');

      // Bản ghi tạo trước migration V2 không có cột title.
      final legacy = Phrase.fromJson(const {
        'id': 8,
        'text': 'I am writing to apply for the position.',
        'correctedText': 'I am writing to apply for the position.',
        'score': 10,
      });
      expect(legacy.title, isEmpty);
      expect(legacy.displayTitle, '[Không có tiêu đề]');
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
      // Chỉ còn MỘT nút OCR (trong thẻ nhập liệu); icon trên AppBar đã bị bỏ
      // vì trùng chức năng.
      expect(find.byIcon(Icons.document_scanner_rounded), findsOneWidget);
    });

    testWidgets('PhraseFormScreen có ô nhập tiêu đề đoạn văn (act-11)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<PhraseApi>.value(
            value: api,
            child: const PhraseFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tiêu đề đoạn văn'), findsOneWidget);
      expect(find.byIcon(Icons.title_rounded), findsOneWidget);
      // Gợi ý nêu rõ nhãn mặc định để người dùng biết trước khi bỏ trống.
      expect(
        find.textContaining('[Không có tiêu đề]'),
        findsOneWidget,
      );
    });

    testWidgets('PhraseListScreen hiển thị tiêu đề từng đoạn văn (act-10)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PhraseListController>.value(
            value: listController,
            child: const PhraseListScreen(),
          ),
        ),
      );
      // MockPhraseApi dùng Future.delayed: trong testWidgets timer là timer giả,
      // nên phải chạy load() qua runAsync để timer thật hoàn tất (await thẳng
      // load() ở đây sẽ treo vô hạn).
      await tester.runAsync(listController.load);
      await tester.pump();

      // 3 bài seed đều có tiêu đề riêng.
      expect(find.text('Kể về ngày hôm qua'), findsOneWidget);
      expect(find.text('Câu ghép với Although'), findsOneWidget);
      expect(find.text('Tầm quan trọng của tiếng Anh'), findsOneWidget);
      // Nội dung đoạn văn vẫn nằm dưới tiêu đề, không bị thay thế.
      expect(find.textContaining('I has went to school'), findsOneWidget);
    });

    testWidgets('Hộp thoại xoá bài nêu tiêu đề đoạn văn (act-10)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PhraseListController>.value(
            value: listController,
            child: const PhraseListScreen(),
          ),
        ),
      );
      await tester.runAsync(listController.load);
      await tester.pump();

      // Danh sách sắp theo id tăng dần (giống backend) → bài cũ nhất nằm đầu.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa bài này').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('"Kể về ngày hôm qua"'),
        findsOneWidget,
      );
    });

    test('Bài mới chấm xong được thêm vào cuối, giữ thứ tự id tăng dần như backend', () async {
      await listController.load();
      final before = listController.phrases.map((p) => p.id).toList();
      expect(before, orderedEquals([...before]..sort()));

      formController.setText('A brand new sentence appended at the end of the notebook.');
      final created = await formController.submitForGrading();
      expect(created, isNotNull);

      listController.addOrUpdatePhrase(created!);

      final after = listController.phrases;
      expect(after.last.id, created.id);
      final ids = after.map((p) => p.id).toList();
      expect(ids, orderedEquals([...ids]..sort()));
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

    testWidgets('Tiêu đề gõ trên form được gửi nguyên văn lên API (act-11)', (tester) async {
      final recorder = _RecordingPhraseApi();
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<PhraseApi>.value(value: recorder),
              ChangeNotifierProvider<PhraseListController>(
                create: (_) => PhraseListController(recorder),
              ),
            ],
            child: const PhraseFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // TextField 0 = ô tiêu đề, TextField 1 = ô đoạn văn.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Luyện viết IELTS');
      await tester.enterText(
        fields.at(1),
        'Although online learning is convenient, it requires self discipline.',
      );
      await tester.pump();

      await tester.tap(find.text('Chấm điểm & Sửa lỗi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Đây là điểm chốt: nếu tiêu đề không tới được API thì lỗi nằm ở FE.
      expect(recorder.lastTitle, 'Luyện viết IELTS');
      expect(recorder.lastText, contains('Although online learning'));
      expect(recorder.lastTitle, isNot(Phrase.untitledLabel));
    });

    testWidgets('Để trống ô tiêu đề thì gửi nhãn mặc định (act-11)', (tester) async {      final recorder = _RecordingPhraseApi();
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<PhraseApi>.value(value: recorder),
              ChangeNotifierProvider<PhraseListController>(
                create: (_) => PhraseListController(recorder),
              ),
            ],
            child: const PhraseFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(1),
        'This sentence has no title but is long enough to pass validation.',
      );
      await tester.pump();

      await tester.tap(find.text('Chấm điểm & Sửa lỗi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(recorder.lastTitle, Phrase.untitledLabel);
    });
  });
}

/// Fake API chỉ ghi lại tham số mà form gửi lên, dùng để kiểm chứng luồng
/// "gõ tiêu đề → bấm chấm điểm" mà không phụ thuộc backend.
class _RecordingPhraseApi implements PhraseApi {
  String? lastTitle;
  String? lastText;

  @override
  Future<Phrase> createPhrase(String title, String text) async {
    lastTitle = title;
    lastText = text;
    return Phrase(
      id: 99,
      title: title,
      text: text,
      correctedText: text,
      score: 10,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<List<Phrase>> fetchPhrases() async => const <Phrase>[];

  @override
  Future<void> deletePhrase(int id) async {}
}
