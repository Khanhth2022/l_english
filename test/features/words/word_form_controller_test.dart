import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/network/api_exception.dart';
import 'package:l_english/features/words/data/mock_word_api.dart';
import 'package:l_english/features/words/data/models/enums.dart';
import 'package:l_english/features/words/data/models/word.dart';
import 'package:l_english/features/words/data/models/word_draft.dart';
import 'package:l_english/features/words/data/models/word_value.dart';
import 'package:l_english/features/words/data/word_api.dart';
import 'package:l_english/features/words/state/word_form_controller.dart';

class _RecordingWordApi implements WordApi {
  WordDraft? createdDraft;
  int? updatedId;

  @override
  Future<List<Word>> fetchWords() async => const [];

  @override
  Future<Word> createWord(WordDraft draft) async {
    createdDraft = draft;
    return Word(id: 1, english: draft.english, values: draft.values);
  }

  @override
  Future<Word> updateWord(int id, WordDraft draft) async {
    updatedId = id;
    return Word(id: id, english: draft.english, values: draft.values);
  }

  @override
  Future<void> deleteWord(int id) async {}

  @override
  Future<List<WordValue>> generateMeaning(String english) async =>
      throw ApiException(502, 'Dịch vụ AI không phản hồi, vui lòng thử lại.');

  @override
  Future<void> confirmReview(List<int> wordIds) async {}
}

void main() {
  late MockWordApi api;

  setUp(() => api = MockWordApi(latency: Duration.zero));

  test('form trống bắt đầu với một dòng nghĩa', () {
    final controller = WordFormController(api: api);
    addTearDown(controller.dispose);

    expect(controller.isEditing, isFalse);
    expect(controller.title, 'Thêm từ');
    expect(controller.rows.length, 1);
    expect(controller.level, isNull);
  });

  test('mở form sửa từ thì nạp sẵn dữ liệu cũ', () async {
    final existing = (await api.fetchWords()).firstWhere(
      (word) => word.english == 'achieve',
    );
    final controller = WordFormController(api: api, existing: existing);
    addTearDown(controller.dispose);

    expect(controller.isEditing, isTrue);
    expect(controller.title, 'Sửa từ');
    expect(controller.englishController.text, 'achieve');
    expect(controller.level, Level.b1);
    expect(controller.rows.length, existing.values.length);
    expect(controller.rows.first.vietnameseController.text, 'đạt được, giành được');
    expect(controller.rows.first.partOfSpeech, PartOfSpeech.verb);
  });

  test('gợi ý nghĩa bằng AI thì thay các dòng nghĩa hiện có', () async {
    final controller = WordFormController(api: api);
    addTearDown(controller.dispose);
    controller.englishController.text = 'resilient';

    final error = await controller.generateMeaning();

    expect(error, isNull);
    expect(controller.generating, isFalse);
    expect(controller.rows.length, 2);
    expect(controller.rows.first.vietnameseController.text, 'kiên cường, mau hồi phục');
    expect(controller.notice, 'Đã điền 2 nghĩa cho "resilient".');
    expect(api.aiCallCount, 1);

    // Gọi lần nữa: backend trả từ cache nên không gọi AI thêm.
    await controller.generateMeaning();
    expect(api.aiCallCount, 1);
  });

  test('chưa nhập từ tiếng Anh thì không gọi AI', () async {
    final controller = WordFormController(api: api);
    addTearDown(controller.dispose);

    final error = await controller.generateMeaning();

    expect(error, 'Nhập từ tiếng Anh trước khi nhờ AI sinh nghĩa.');
    expect(api.aiCallCount, 0);
  });

  test('lỗi 502 của dịch vụ AI được chuyển thành thông báo', () async {
    final controller = WordFormController(api: _RecordingWordApi());
    addTearDown(controller.dispose);
    controller.englishController.text = 'resilient';

    final error = await controller.generateMeaning();

    expect(error, 'Dịch vụ AI không phản hồi, vui lòng thử lại.');
    expect(controller.generating, isFalse);
  });

  test('thêm và bớt dòng nghĩa, luôn giữ ít nhất một dòng', () {
    final controller = WordFormController(api: api);
    addTearDown(controller.dispose);

    controller.addRow();
    expect(controller.rows.length, 2);

    controller.removeRow(controller.rows.last);
    expect(controller.rows.length, 1);

    controller.removeRow(controller.rows.first);
    expect(controller.rows.length, 1);
  });

  test('save() kiểm tra dữ liệu trước khi gọi backend', () async {
    final recording = _RecordingWordApi();
    final controller = WordFormController(api: recording);
    addTearDown(controller.dispose);

    expect(await controller.save(), 'Nhập từ tiếng Anh.');

    controller.englishController.text = 'lucid';
    expect(await controller.save(), 'Cần ít nhất một nghĩa tiếng Việt.');

    expect(recording.createdDraft, isNull);
    expect(controller.saving, isFalse);
  });

  test('save() tạo từ mới với dữ liệu đã nhập', () async {
    final recording = _RecordingWordApi();
    final controller = WordFormController(api: recording);
    addTearDown(controller.dispose);

    controller.englishController.text = '  lucid  ';
    controller.setLevel(Level.c1);
    controller.rows.first.vietnameseController.text = 'trong sáng';
    controller.rows.first.exampleController.text = 'a lucid explanation';
    controller.setPartOfSpeech(controller.rows.first, PartOfSpeech.adjective);

    expect(await controller.save(), isNull);
    expect(recording.createdDraft?.english, 'lucid');
    expect(recording.createdDraft?.level, Level.c1);
    expect(recording.createdDraft?.values.single.example, 'a lucid explanation');
    expect(recording.createdDraft?.values.single.partOfSpeech, PartOfSpeech.adjective);
  });

  test('save() khi sửa từ thì gọi updateWord với đúng id', () async {
    final recording = _RecordingWordApi();
    const existing = Word(
      id: 42,
      english: 'lucid',
      values: [WordValue(vietnamese: 'trong sáng')],
    );
    final controller = WordFormController(api: recording, existing: existing);
    addTearDown(controller.dispose);

    controller.englishController.text = 'lucid';
    controller.rows.first.vietnameseController.text = 'rõ ràng, trong sáng';

    expect(await controller.save(), isNull);
    expect(recording.updatedId, 42);
    expect(recording.createdDraft, isNull);
  });

  test('save() trả về lỗi 409 khi từ bị trùng', () async {
    final controller = WordFormController(api: api);
    addTearDown(controller.dispose);

    controller.englishController.text = 'curious';
    controller.rows.first.vietnameseController.text = 'tò mò';

    final error = await controller.save();

    expect(error, 'Từ "curious" đã có trong sổ từ của bạn.');
    expect(controller.saving, isFalse);
  });
}
