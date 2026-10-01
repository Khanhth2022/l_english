import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/network/api_exception.dart';
import 'package:l_english/features/words/data/mock_word_api.dart';
import 'package:l_english/features/words/data/models/word.dart';
import 'package:l_english/features/words/data/models/word_draft.dart';
import 'package:l_english/features/words/data/models/word_value.dart';
import 'package:l_english/features/words/data/word_api.dart';
import 'package:l_english/features/words/state/word_list_controller.dart';

/// API luôn lỗi, dùng để kiểm tra nhánh thất bại của màn hình.
class _FailingWordApi implements WordApi {
  @override
  Future<List<Word>> fetchWords() async =>
      throw ApiException(500, 'Lỗi máy chủ khi tải danh sách từ.');

  @override
  Future<Word> createWord(WordDraft draft) async => throw UnimplementedError();

  @override
  Future<Word> updateWord(int id, WordDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteWord(int id) async =>
      throw ApiException(403, 'Không tìm thấy từ này trong sổ từ của bạn.');

  @override
  Future<List<WordValue>> generateMeaning(String english) async =>
      throw UnimplementedError();

  @override
  Future<void> confirmReview(List<int> wordIds) async =>
      throw UnimplementedError();
}

void main() {
  late MockWordApi api;
  late WordListController controller;

  setUp(() {
    api = MockWordApi(latency: Duration.zero);
    controller = WordListController(api);
  });

  tearDown(() => controller.dispose());

  test('load() thành công thì có 4 từ và 2 từ đến hạn', () async {
    await controller.load();

    expect(controller.status, LoadStatus.success);
    expect(controller.errorMessage, isNull);
    expect(controller.words.length, 4);
    // achieve đã quá hạn, curious là từ mới chưa từng ôn.
    expect(controller.dueCount, 2);
  });

  test('load() thất bại thì giữ thông báo lỗi của backend', () async {
    final failing = WordListController(_FailingWordApi());
    addTearDown(failing.dispose);

    await failing.load();

    expect(failing.status, LoadStatus.failure);
    expect(failing.errorMessage, 'Lỗi máy chủ khi tải danh sách từ.');
  });

  test('tab Ôn tập chỉ giữ từ có next_review <= now', () async {
    await controller.load();
    controller.setOnlyDue(true);

    expect(controller.visibleWords.map((word) => word.english), [
      'achieve',
      'curious',
    ]);
  });

  test('tìm kiếm khớp cả từ tiếng Anh lẫn nghĩa tiếng Việt', () async {
    await controller.load();

    controller.setQuery('dili');
    expect(controller.visibleWords.single.english, 'diligent');

    controller.setQuery('lợi ích');
    expect(controller.visibleWords.single.english, 'benefit');

    controller.setQuery('không có từ nào như vậy');
    expect(controller.visibleWords, isEmpty);
  });

  test('chọn từ để ôn, bỏ chọn và rời tab thì xoá lựa chọn', () async {
    await controller.load();
    controller.setOnlyDue(true);

    controller.toggleSelected(1);
    controller.toggleSelected(3);
    expect(controller.selectedCount, 2);
    expect(controller.isSelected(1), isTrue);

    controller.toggleSelected(1);
    expect(controller.selectedCount, 1);

    controller.setOnlyDue(false);
    expect(controller.selectedCount, 0, reason: 'rời tab Ôn tập thì bỏ chọn hết');
  });

  test('xoá từ thành công thì bỏ khỏi danh sách', () async {
    await controller.load();
    final target = controller.words.first;

    final error = await controller.deleteWord(target);

    expect(error, isNull);
    expect(controller.words.length, 3);
    expect(controller.words.any((word) => word.id == target.id), isFalse);
  });

  test('xoá từ thất bại thì trả thông báo lỗi và giữ nguyên danh sách', () async {
    final failing = WordListController(_FailingWordApi());
    addTearDown(failing.dispose);
    const word = Word(id: 9, english: 'ghost');

    final error = await failing.deleteWord(word);

    expect(error, 'Không tìm thấy từ này trong sổ từ của bạn.');
  });

  test('xác nhận ôn tập khi chưa chọn gì thì báo lỗi', () async {
    await controller.load();

    final error = await controller.confirmReview();

    expect(error, 'Chưa chọn từ nào để xác nhận ôn tập.');
  });

  test('xác nhận ôn tập cập nhật SRS rồi tải lại danh sách', () async {
    await controller.load();
    controller.setOnlyDue(true);
    final achieve = controller.words.firstWhere((w) => w.english == 'achieve');
    controller.toggleSelected(achieve.id);

    final error = await controller.confirmReview();

    expect(error, isNull);
    expect(controller.submitting, isFalse);
    expect(controller.selectedCount, 0);

    final updated = controller.words.firstWhere(
      (w) => w.id == achieve.id,
    );
    expect(updated.reviewCount, achieve.reviewCount + 1);
    expect(updated.isDue(DateTime.now()), isFalse);
    expect(controller.dueCount, 1, reason: 'chỉ còn từ mới curious đến hạn');
  });
}
