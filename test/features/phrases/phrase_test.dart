import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/features/phrases/data/mock_phrase_api.dart';
import 'package:l_english/features/phrases/state/phrase_form_controller.dart';
import 'package:l_english/features/phrases/state/phrase_list_controller.dart';

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
  });
}
