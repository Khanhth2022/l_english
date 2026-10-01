import '../../../core/network/api_exception.dart';
import 'models/enums.dart';
import 'models/word.dart';
import 'models/word_draft.dart';
import 'models/word_value.dart';
import 'word_api.dart';

/// API giả chạy hoàn toàn trong bộ nhớ, để app dùng được khi backend Java chưa xong.
///
/// Bản này mô phỏng đúng các quy ước trong tài liệu thiết kế:
/// * `400` – từ để trống hoặc không phải tiếng Anh;
/// * `403` – sửa/xoá từ không thuộc người dùng đang đăng nhập;
/// * `409` – trùng từ, tương ứng ràng buộc UNIQUE (user_id, english);
/// * `502` – dịch vụ AI lỗi (bật bằng [simulateAiFailure]);
/// * sinh nghĩa theo hướng cache-first: từ đã có trong "cache" thì trả ngay,
///   không gọi AI;
/// * luật SRS: `review_count += 1` rồi giãn cách 1, 2, 4, 7, 15, 30 ngày.
///
/// Logic thật nằm ở `WordService` phía backend; đây chỉ là bản mô phỏng.
class MockWordApi implements WordApi {
  MockWordApi({
    this.latency = const Duration(milliseconds: 350),
    this.simulateAiFailure = false,
  }) {
    _seed();
  }

  /// Độ trễ giả cho mỗi lời gọi (đặt `Duration.zero` khi viết test).
  final Duration latency;

  /// Bật để thử luồng lỗi 502 của chức năng sinh nghĩa.
  bool simulateAiFailure;

  /// Số lần thật sự "gọi AI" — dùng để thấy cache có tác dụng.
  int aiCallCount = 0;

  /// Lần sinh nghĩa gần nhất có lấy từ cache hay không.
  bool lastGenerateFromCache = false;

  final Map<int, Word> _words = {};
  final Map<String, List<WordValue>> _wordCache = {};
  int _nextId = 1;

  /// Giãn cách ôn tập theo số lần đã ôn, đúng dãy trong tài liệu thiết kế.
  static const List<int> reviewIntervals = [1, 2, 4, 7, 15, 30];

  /// Số ngày tới lần ôn kế tiếp sau khi đã ôn [reviewCount] lần.
  /// Từ lần thứ 6 trở đi giữ mức 30 ngày.
  static int intervalDays(int reviewCount) {
    if (reviewCount <= 0) return reviewIntervals.first;
    final index = reviewCount - 1;
    return index < reviewIntervals.length
        ? reviewIntervals[index]
        : reviewIntervals.last;
  }

  /// Backend kiểm tra `english` phải là tiếng Anh trước khi lưu/gọi AI.
  static final RegExp _englishPattern = RegExp(r"^[A-Za-z][A-Za-z'\-\. ]*$");

  static bool looksLikeEnglish(String text) =>
      _englishPattern.hasMatch(text.trim());

  // ---------------------------------------------------------------- WordApi

  @override
  Future<List<Word>> fetchWords() async {
    await _delay();
    return _words.values.toList()
      ..sort(
        (a, b) => a.english.toLowerCase().compareTo(b.english.toLowerCase()),
      );
  }

  @override
  Future<Word> createWord(WordDraft draft) async {
    await _delay();
    final english = draft.english.trim();
    _validateEnglish(english);
    if (_findByEnglish(english) != null) {
      throw ApiException(409, 'Từ "$english" đã có trong sổ từ của bạn.');
    }
    final now = DateTime.now();
    final id = _nextId++;
    final word = Word(
      id: id,
      english: english,
      level: draft.level,
      // Từ mới chưa có lịch ôn nên sẽ nằm trong tab "Ôn tập".
      nextReview: null,
      createdAt: now,
      updatedAt: now,
      values: _cleanValues(draft.values),
    );
    _words[id] = word;
    return word;
  }

  @override
  Future<Word> updateWord(int id, WordDraft draft) async {
    await _delay();
    final current = _requireOwned(id);
    final english = draft.english.trim();
    _validateEnglish(english);
    final duplicate = _findByEnglish(english);
    if (duplicate != null && duplicate.id != id) {
      throw ApiException(409, 'Từ "$english" đã có trong sổ từ của bạn.');
    }
    final updated = Word(
      id: id,
      english: english,
      level: draft.level,
      // Kết quả ôn tập giữ nguyên, chỉ nội dung từ bị thay đổi.
      reviewCount: current.reviewCount,
      nextReview: current.nextReview,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      values: _cleanValues(draft.values),
    );
    _words[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteWord(int id) async {
    await _delay();
    _requireOwned(id);
    _words.remove(id);
  }

  @override
  Future<List<WordValue>> generateMeaning(String english) async {
    final text = english.trim();
    if (text.isEmpty) {
      throw ApiException(400, 'Nhập từ tiếng Anh trước khi nhờ AI sinh nghĩa.');
    }
    if (!looksLikeEnglish(text)) {
      throw ApiException(400, '"$text" không phải là một từ tiếng Anh hợp lệ.');
    }

    final cached = _wordCache[text.toLowerCase()];
    if (cached != null) {
      // Cache-first: không gọi AI, không tốn độ trễ.
      lastGenerateFromCache = true;
      return cached;
    }

    await _delay();
    if (simulateAiFailure) {
      throw ApiException(502, 'Dịch vụ AI không phản hồi, vui lòng thử lại.');
    }
    lastGenerateFromCache = false;
    aiCallCount++;
    final generated =
        _dictionary[text.toLowerCase()] ?? _synthesize(text);
    _wordCache[text.toLowerCase()] = generated;
    return generated;
  }

  @override
  Future<void> confirmReview(List<int> wordIds) async {
    await _delay();
    if (wordIds.isEmpty) {
      throw ApiException(400, 'Chưa chọn từ nào để xác nhận ôn tập.');
    }
    final now = DateTime.now();
    for (final id in wordIds) {
      final word = _requireOwned(id);
      final reviewCount = word.reviewCount + 1;
      _words[id] = Word(
        id: word.id,
        english: word.english,
        level: word.level,
        reviewCount: reviewCount,
        nextReview: now.add(Duration(days: intervalDays(reviewCount))),
        createdAt: word.createdAt,
        updatedAt: now,
        values: word.values,
      );
    }
  }

  // ------------------------------------------------------------------ Nội bộ

  Future<void> _delay() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }

  void _validateEnglish(String english) {
    if (english.isEmpty) {
      throw ApiException(400, 'Từ tiếng Anh không được để trống.');
    }
    if (!looksLikeEnglish(english)) {
      throw ApiException(400, '"$english" không phải là một từ tiếng Anh hợp lệ.');
    }
  }

  /// Backend trả 403 khi bản ghi không thuộc người dùng đang đăng nhập (IDOR).
  /// Mock chỉ có dữ liệu của chính mình nên "không tìm thấy" cũng trả 403.
  Word _requireOwned(int id) {
    final word = _words[id];
    if (word == null) {
      throw ApiException(403, 'Không tìm thấy từ này trong sổ từ của bạn.');
    }
    return word;
  }

  Word? _findByEnglish(String english) {
    final key = english.toLowerCase();
    for (final word in _words.values) {
      if (word.english.toLowerCase() == key) return word;
    }
    return null;
  }

  List<WordValue> _cleanValues(List<WordValue> values) {
    final cleaned = values
        .where((value) => !value.isBlank)
        .map(
          (value) => WordValue(
            vietnamese: value.vietnamese.trim(),
            example: value.example?.trim(),
            exampleTranslation: value.exampleTranslation?.trim(),
            pronunciation: value.pronunciation?.trim(),
            partOfSpeech: value.partOfSpeech,
          ),
        )
        .toList();
    if (cleaned.isEmpty) {
      throw ApiException(400, 'Cần ít nhất một nghĩa tiếng Việt cho từ.');
    }
    return cleaned;
  }

  List<WordValue> _synthesize(String text) => [
    WordValue(
      vietnamese: 'nghĩa thứ nhất của "$text" (do AI sinh)',
      pronunciation: '/${text.toLowerCase()}/',
      partOfSpeech: PartOfSpeech.noun,
    ),
    WordValue(
      vietnamese: 'nghĩa thứ hai của "$text" (do AI sinh)',
      example: 'This is an example with $text.',
      exampleTranslation: 'Đây là ví dụ với $text.',
      partOfSpeech: PartOfSpeech.verb,
    ),
  ];

  /// "Từ điển" nhỏ để bản demo trả về nghĩa thật thay vì nghĩa máy sinh.
  static final Map<String, List<WordValue>> _dictionary = {
    'resilient': const [
      WordValue(
        vietnamese: 'kiên cường, mau hồi phục',
        pronunciation: '/rɪˈzɪliənt/',
        partOfSpeech: PartOfSpeech.adjective,
        example: 'Children are usually resilient.',
        exampleTranslation: 'Trẻ con thường rất kiên cường.',
      ),
      WordValue(
        vietnamese: 'có sức bật, đàn hồi',
        partOfSpeech: PartOfSpeech.adjective,
      ),
    ],
    'insight': const [
      WordValue(
        vietnamese: 'sự hiểu biết sâu sắc',
        pronunciation: '/ˈɪnsaɪt/',
        partOfSpeech: PartOfSpeech.noun,
        example: 'The book gives an insight into his life.',
        exampleTranslation: 'Cuốn sách cho ta hiểu sâu về cuộc đời ông ấy.',
      ),
    ],
    'reluctantly': const [
      WordValue(
        vietnamese: 'một cách miễn cưỡng',
        pronunciation: '/rɪˈlʌktəntli/',
        partOfSpeech: PartOfSpeech.adverb,
        example: 'She reluctantly agreed.',
        exampleTranslation: 'Cô ấy miễn cưỡng đồng ý.',
      ),
    ],
  };

  void _seed() {
    final now = DateTime.now();
    void add({
      required String english,
      required Level level,
      required List<WordValue> values,
      int reviewCount = 0,
      Duration? dueIn,
    }) {
      final id = _nextId++;
      _words[id] = Word(
        id: id,
        english: english,
        level: level,
        reviewCount: reviewCount,
        nextReview: dueIn == null ? null : now.add(dueIn),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 1)),
        values: values,
      );
      _wordCache[english.toLowerCase()] = values;
    }

    add(
      english: 'achieve',
      level: Level.b1,
      reviewCount: 2,
      dueIn: const Duration(days: -1), // đã quá hạn ôn
      values: const [
        WordValue(
          vietnamese: 'đạt được, giành được',
          pronunciation: '/əˈtʃiːv/',
          partOfSpeech: PartOfSpeech.verb,
          example: 'She achieved her goal.',
          exampleTranslation: 'Cô ấy đã đạt được mục tiêu.',
        ),
        WordValue(
          vietnamese: 'hoàn thành xuất sắc',
          partOfSpeech: PartOfSpeech.verb,
        ),
      ],
    );

    add(
      english: 'benefit',
      level: Level.a2,
      reviewCount: 1,
      dueIn: const Duration(days: 3),
      values: const [
        WordValue(
          vietnamese: 'lợi ích, ích lợi',
          pronunciation: '/ˈbenɪfɪt/',
          partOfSpeech: PartOfSpeech.noun,
          example: 'Regular exercise has many benefits.',
          exampleTranslation: 'Tập thể dục đều đặn có nhiều lợi ích.',
        ),
      ],
    );

    add(
      english: 'curious',
      level: Level.a2,
      values: const [
        WordValue(
          vietnamese: 'tò mò, ham tìm hiểu',
          pronunciation: '/ˈkjʊəriəs/',
          partOfSpeech: PartOfSpeech.adjective,
          example: 'I am curious about space.',
          exampleTranslation: 'Tôi tò mò về vũ trụ.',
        ),
        WordValue(
          vietnamese: 'kỳ lạ, lạ lùng',
          partOfSpeech: PartOfSpeech.adjective,
        ),
      ],
    );

    add(
      english: 'diligent',
      level: Level.b2,
      reviewCount: 3,
      dueIn: const Duration(days: 12),
      values: const [
        WordValue(
          vietnamese: 'siêng năng, cần mẫn',
          pronunciation: '/ˈdɪlɪdʒənt/',
          partOfSpeech: PartOfSpeech.adjective,
          example: 'He is a diligent student.',
          exampleTranslation: 'Cậu ấy là một học sinh siêng năng.',
        ),
      ],
    );
  }
}
