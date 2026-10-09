import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/features/words/data/mock_word_api.dart';

void main() {
  group('Topic Words (act-20, seq-20)', () {
    late MockWordApi api;

    setUp(() {
      api = MockWordApi(latency: Duration.zero);
    });

    test('generateTopicWords sinh đủ 10 từ theo chủ đề công sở', () async {
      final words = await api.generateTopicWords('công sở');
      expect(words.length, 10);
      expect(words.any((w) => w.english == 'colleague'), isTrue);
      expect(words.any((w) => w.english == 'deadline'), isTrue);
    });

    test('generateTopicWords loại trừ các từ đã có trong sổ', () async {
      final initialWords = await api.fetchWords();
      final existingNames = initialWords.map((w) => w.english.toLowerCase()).toSet();

      final generated = await api.generateTopicWords('du lịch');
      for (final w in generated) {
        expect(existingNames.contains(w.english.toLowerCase()), isFalse);
      }
    });

    test('confirmTopicWords ghi nhận các từ đã chọn vào sổ từ', () async {
      final initialCount = (await api.fetchWords()).length;
      final generated = await api.generateTopicWords('du lịch');
      final toAdd = generated.take(3).toList();

      final added = await api.confirmTopicWords(toAdd);
      expect(added.length, 3);

      final newTotal = (await api.fetchWords()).length;
      expect(newTotal, initialCount + 3);

      // Từ mới thêm đến hạn ôn ngay
      final dueCount = await api.fetchDueCount();
      expect(dueCount, greaterThanOrEqualTo(3));
    });

    test('Chủ đề để trống bị từ chối 400', () async {
      expect(
        () => api.generateTopicWords('   '),
        throwsA(anything),
      );
    });
  });
}
