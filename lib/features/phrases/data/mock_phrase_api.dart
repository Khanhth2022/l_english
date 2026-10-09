import '../../../core/network/api_exception.dart';
import 'models/phrase_models.dart';
import 'phrase_api.dart';

/// Giả lập API Chấm đoạn văn bằng AI in-memory khi không có backend hoặc ngoại tuyến.
class MockPhraseApi implements PhraseApi {
  MockPhraseApi({
    this.latency = const Duration(milliseconds: 400),
    this.simulateAiFailure = false,
  }) {
    _seed();
  }

  final Duration latency;
  bool simulateAiFailure;

  final Map<int, Phrase> _phrases = {};
  int _nextId = 1;

  void _seed() {
    final now = DateTime.now().subtract(const Duration(days: 1));
    _phrases[_nextId] = Phrase(
      id: _nextId++,
      text: 'I has went to school yesterday with my best friends.',
      correctedText: 'I went to school yesterday with my best friends.',
      score: 6,
      createdAt: now,
      errors: const [
        GrammarError(
          incorrect: 'I has went',
          correction: 'I went',
          explanation: 'Hành động xảy ra và kết thúc trong quá khứ (yesterday) phải dùng thì Quá khứ đơn (Past Simple), không dùng "has went".',
        ),
      ],
    );

    _phrases[_nextId] = Phrase(
      id: _nextId++,
      text: 'Although it was raining heavily, but we still decided to go camping.',
      correctedText: 'Although it was raining heavily, we still decided to go camping.',
      score: 7,
      createdAt: now.add(const Duration(hours: 3)),
      errors: const [
        GrammarError(
          incorrect: 'Although ..., but',
          correction: 'Although ..., [không dùng but]',
          explanation: 'Trong tiếng Anh không dùng cặp liên từ "Although ... but" trong cùng một câu ghép. Hãy bỏ liên từ "but".',
        ),
      ],
    );

    _phrases[_nextId] = Phrase(
      id: _nextId++,
      text: 'English has become an essential language in the modern globalization era.',
      correctedText: 'English has become an essential language in the modern globalization era.',
      score: 10,
      createdAt: DateTime.now(),
      errors: const [],
    );
  }

  @override
  Future<List<Phrase>> fetchPhrases() async {
    await Future.delayed(latency);
    final list = _phrases.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id)); // Mới nhất lên đầu
    return list;
  }

  @override
  Future<Phrase> createPhrase(String rawText) async {
    await Future.delayed(latency + const Duration(milliseconds: 300));
    final text = rawText.trim();

    if (simulateAiFailure) {
      throw ApiException(502, 'Dịch vụ AI tạm thời không khả dụng. Vui lòng thử lại sau.');
    }

    if (text.length < 10) {
      throw ApiException(400, 'Đoạn văn gửi lên không hợp lệ. Vui lòng nhập tối thiểu 10 ký tự.');
    }

    // Mô phỏng AI phân tích câu và phát hiện lỗi
    final errors = <GrammarError>[];
    var corrected = text;

    void checkPattern(String pattern, String replacement, String explanation) {
      final reg = RegExp(pattern, caseSensitive: false);
      if (reg.hasMatch(corrected)) {
        errors.add(GrammarError(
          incorrect: reg.firstMatch(corrected)?.group(0),
          correction: replacement,
          explanation: explanation,
        ));
        corrected = corrected.replaceAll(reg, replacement);
      }
    }

    checkPattern(
      r'\bhas went\b',
      'went',
      'Sau trợ động từ "has" cần dùng quá khứ phân từ "gone", hoặc thì quá khứ đơn "went" khi có trạng từ chỉ thời gian.',
    );
    checkPattern(
      r"\bhe don't\b",
      "he doesn't",
      'Chủ ngữ ngôi thứ 3 số ít "He" đi với trợ động từ phủ định "doesn\'t".',
    );
    checkPattern(
      r"\bshe don't\b",
      "she doesn't",
      'Chủ ngữ ngôi thứ 3 số ít "She" đi với trợ động từ phủ định "doesn\'t".',
    );
    checkPattern(
      r'\bmore better\b',
      'better',
      '"Better" là tính từ so sánh hơn bất quy tắc, không đi kèm "more".',
    );
    checkPattern(
      r'\bAlthough (.*?), but\b',
      'Although \$1,',
      'Không dùng cặp liên từ "Although ... but" đồng thời trong câu tiếng Anh.',
    );
    checkPattern(
      r'\bdepend of\b',
      'depend on',
      'Động từ "depend" đi với giới từ "on" (phụ thuộc vào).',
    );
    checkPattern(
      r'\blook forward to hear\b',
      'look forward to hearing',
      'Cấu trúc "look forward to + V-ing" (mong đợi điều gì).',
    );

    // Tính điểm 0-10
    int calculatedScore;
    if (errors.isEmpty) {
      calculatedScore = text.length > 50 ? 10 : 9;
    } else if (errors.length == 1) {
      calculatedScore = 7;
    } else if (errors.length == 2) {
      calculatedScore = 5;
    } else {
      calculatedScore = 3;
    }

    final id = _nextId++;
    final phrase = Phrase(
      id: id,
      text: text,
      correctedText: corrected,
      score: calculatedScore,
      createdAt: DateTime.now(),
      errors: errors,
    );

    _phrases[id] = phrase;
    return phrase;
  }

  @override
  Future<void> deletePhrase(int id) async {
    await Future.delayed(latency);
    if (!_phrases.containsKey(id)) {
      throw ApiException(403, 'Không có quyền xóa đoạn văn này.');
    }
    _phrases.remove(id);
  }
}
