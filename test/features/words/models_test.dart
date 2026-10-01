import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/features/words/data/models/enums.dart';
import 'package:l_english/features/words/data/models/word.dart';
import 'package:l_english/features/words/data/models/word_value.dart';

void main() {
  group('Level.tryParse', () {
    test('đọc được giá trị backend trả về, không phân biệt hoa thường', () {
      expect(Level.tryParse('B1'), Level.b1);
      expect(Level.tryParse(' b1 '), Level.b1);
      expect(Level.tryParse('c2'), Level.c2);
    });

    test('trả null với giá trị lạ thay vì ném lỗi', () {
      expect(Level.tryParse('Z9'), isNull);
      expect(Level.tryParse(null), isNull);
      expect(Level.tryParse(3), isNull);
    });
  });

  group('PartOfSpeech.tryParse', () {
    test('đọc được cả tên enum HOA của Jackson lẫn chữ thường trong MySQL', () {
      expect(PartOfSpeech.tryParse('NOUN'), PartOfSpeech.noun);
      expect(PartOfSpeech.tryParse('noun'), PartOfSpeech.noun);
      expect(PartOfSpeech.tryParse('Adjective'), PartOfSpeech.adjective);
      expect(PartOfSpeech.tryParse('part-of-speech'), isNull);
    });

    test('trả null với giá trị lạ', () {
      expect(PartOfSpeech.tryParse('determiner'), isNull);
      expect(PartOfSpeech.tryParse(''), isNull);
      expect(PartOfSpeech.tryParse(null), isNull);
    });

    test('apiValue là chữ hoa để khớp @Enumerated(EnumType.STRING)', () {
      expect(PartOfSpeech.verb.apiValue, 'VERB');
      expect(PartOfSpeech.verb.dbValue, 'verb');
      expect(PartOfSpeech.adverb.label, 'Trạng từ');
    });
  });

  group('Word.fromJson', () {
    test('đọc đúng JSON camelCase do backend trả về', () {
      final word = Word.fromJson({
        'id': 7,
        'english': 'achieve',
        'level': 'B1',
        'reviewCount': 2,
        'nextReview': '2024-05-01T08:30:00',
        'createdAt': '2024-04-01T08:30:00',
        'values': [
          {
            'id': 11,
            'vietnamese': 'đạt được',
            'partOfSpeech': 'VERB',
            'example': 'She achieved her goal.',
            'pronunciation': '/əˈtʃiːv/',
          },
        ],
      });

      expect(word.id, 7);
      expect(word.english, 'achieve');
      expect(word.level, Level.b1);
      expect(word.reviewCount, 2);
      expect(word.nextReview, DateTime(2024, 5, 1, 8, 30));
      expect(word.values.single.vietnamese, 'đạt được');
      expect(word.values.single.partOfSpeech, PartOfSpeech.verb);
      expect(word.values.single.pronunciation, '/əˈtʃiːv/');
    });

    test('thiếu trường thì dùng mặc định, không ném lỗi', () {
      final word = Word.fromJson({'id': 1, 'english': 'curious'});

      expect(word.level, isNull);
      expect(word.reviewCount, 0);
      expect(word.nextReview, isNull);
      expect(word.values, isEmpty);
    });
  });

  group('Word.isDue', () {
    final now = DateTime(2024, 5, 1, 12);

    test('từ mới chưa có lịch ôn thì luôn đến hạn', () {
      const word = Word(id: 1, english: 'curious');
      expect(word.isDue(now), isTrue);
    });

    test('quá hạn hoặc đúng mốc thì đến hạn', () {
      final overdue = Word(
        id: 2,
        english: 'achieve',
        reviewCount: 2,
        nextReview: now.subtract(const Duration(days: 1)),
      );
      final exactlyDue = Word(id: 3, english: 'benefit', nextReview: now);
      expect(overdue.isDue(now), isTrue);
      expect(exactlyDue.isDue(now), isTrue);
    });

    test('còn hạn thì không nằm trong tab Ôn tập', () {
      final scheduled = Word(
        id: 4,
        english: 'diligent',
        nextReview: now.add(const Duration(days: 3)),
      );
      expect(scheduled.isDue(now), isFalse);
    });
  });

  group('WordValue', () {
    test('toJson gửi partOfSpeech chữ hoa và bỏ id của nghĩa', () {
      const value = WordValue(
        id: 5,
        vietnamese: 'đạt được',
        partOfSpeech: PartOfSpeech.verb,
      );

      expect(value.toJson(), {
        'vietnamese': 'đạt được',
        'example': null,
        'exampleTranslation': null,
        'pronunciation': null,
        'partOfSpeech': 'VERB',
      });
      expect(value.toJson(includeId: true)['id'], 5);
      expect(value.toJson()['partOfSpeech'], 'VERB');
    });

    test('isBlank nhận ra dòng người dùng bỏ trống', () {
      expect(const WordValue(vietnamese: '   ').isBlank, isTrue);
      expect(const WordValue(vietnamese: 'lợi ích').isBlank, isFalse);
    });
  });
}
