import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/network/api_exception.dart';
import 'package:l_english/features/words/data/mock_word_api.dart';
import 'package:l_english/features/words/data/models/enums.dart';
import 'package:l_english/features/words/data/models/word_draft.dart';
import 'package:l_english/features/words/data/models/word_value.dart';

/// Chạy [action] và trả về lỗi [ApiException] mà nó ném ra.
Future<ApiException> captureError(Future<void> Function() action) async {
  try {
    await action();
  } on ApiException catch (error) {
    return error;
  }
  fail('Đáng lẽ phải ném ApiException');
}

void main() {
  late MockWordApi api;

  setUp(() => api = MockWordApi(latency: Duration.zero));

  group('fetchWords', () {
    test('trả về các từ mẫu, sắp xếp theo alphabet', () async {
      final words = await api.fetchWords();
      expect(words.map((word) => word.english), [
        'achieve',
        'benefit',
        'curious',
        'diligent',
      ]);
    });
  });

  group('createWord', () {
    test('thêm từ mới ở trạng thái chưa có lịch ôn', () async {
      final created = await api.createWord(
        const WordDraft(
          english: 'resilient',
          level: Level.b2,
          values: [WordValue(vietnamese: 'kiên cường')],
        ),
      );

      expect(created.english, 'resilient');
      expect(created.level, Level.b2);
      expect(created.reviewCount, 0);
      expect(created.nextReview, isNull, reason: 'từ mới phải vào tab Ôn tập');

      final words = await api.fetchWords();
      expect(words.length, 5);
    });

    test('trùng từ đã có thì trả 409 như ràng buộc UNIQUE(user_id, english)', () async {
      final error = await captureError(() async {
        await api.createWord(
          const WordDraft(
            english: 'Achieve',
            values: [WordValue(vietnamese: 'đạt được')],
          ),
        );
      });

      expect(error.statusCode, 409);
      expect(error.isConflict, isTrue);
    });

    test('chuỗi không phải tiếng Anh thì trả 400', () async {
      final error = await captureError(() async {
        await api.createWord(
          const WordDraft(
            english: 'tiếng Việt',
            values: [WordValue(vietnamese: 'nghĩa')],
          ),
        );
      });

      expect(error.statusCode, 400);
      expect(error.isBadRequest, isTrue);
    });

    test('thiếu nghĩa thì trả 400', () async {
      final error = await captureError(() async {
        await api.createWord(const WordDraft(english: 'lucid'));
      });

      expect(error.statusCode, 400);
    });
  });

  group('updateWord', () {
    test('giữ nguyên kết quả ôn tập, chỉ đổi nội dung từ', () async {
      final before = (await api.fetchWords()).firstWhere(
        (word) => word.english == 'achieve',
      );

      final updated = await api.updateWord(
        before.id,
        const WordDraft(
          english: 'achieve',
          level: Level.c1,
          values: [WordValue(vietnamese: 'giành được')],
        ),
      );

      expect(updated.level, Level.c1);
      expect(updated.reviewCount, before.reviewCount);
      expect(updated.nextReview, before.nextReview);
      expect(updated.values.single.vietnamese, 'giành được');
    });

    test('đổi sang từ đã có trong sổ thì trả 409', () async {
      final benefit = (await api.fetchWords()).firstWhere(
        (word) => word.english == 'benefit',
      );

      final error = await captureError(() async {
        await api.updateWord(
          benefit.id,
          const WordDraft(
            english: 'curious',
            values: [WordValue(vietnamese: 'tò mò')],
          ),
        );
      });

      expect(error.statusCode, 409);
    });

    test('từ không thuộc người dùng thì trả 403 (chống IDOR)', () async {
      final error = await captureError(() async {
        await api.updateWord(
          999,
          const WordDraft(
            english: 'ghost',
            values: [WordValue(vietnamese: 'ma')],
          ),
        );
      });

      expect(error.statusCode, 403);
      expect(error.isForbidden, isTrue);
    });
  });

  group('deleteWord', () {
    test('xoá được từ đang có', () async {
      final target = (await api.fetchWords()).first;
      await api.deleteWord(target.id);

      final words = await api.fetchWords();
      expect(words.any((word) => word.id == target.id), isFalse);
      expect(words.length, 3);
    });

    test('xoá từ không tồn tại thì trả 403', () async {
      final error = await captureError(() => api.deleteWord(999));
      expect(error.statusCode, 403);
    });
  });

  group('generateMeaning (cache-first)', () {
    test('lần đầu gọi AI, lần sau lấy từ cache', () async {
      final first = await api.generateMeaning('resilient');
      expect(api.aiCallCount, 1);
      expect(api.lastGenerateFromCache, isFalse);
      expect(first.first.vietnamese, 'kiên cường, mau hồi phục');
      expect(first.first.partOfSpeech, PartOfSpeech.adjective);

      final second = await api.generateMeaning('Resilient ');
      expect(api.aiCallCount, 1, reason: 'cache trúng thì không gọi AI');
      expect(api.lastGenerateFromCache, isTrue);
      expect(second.length, first.length);
    });

    test('từ lạ vẫn sinh được nghĩa', () async {
      final values = await api.generateMeaning('zigzag');
      expect(values, isNotEmpty);
      expect(values.first.vietnamese, contains('zigzag'));
    });

    test('dịch vụ AI lỗi thì trả 502', () async {
      api.simulateAiFailure = true;
      final error = await captureError(() => api.generateMeaning('zigzag'));

      expect(error.statusCode, 502);
      expect(error.isAiFailure, isTrue);
    });

    test('từ để trống hoặc không phải tiếng Anh thì trả 400', () async {
      expect((await captureError(() => api.generateMeaning('   '))).statusCode, 400);
      expect(
        (await captureError(() => api.generateMeaning('xin chào'))).statusCode,
        400,
      );
    });
  });

  group('confirmReview (spaced repetition)', () {
    test('giãn cách đúng dãy 1, 2, 4, 7, 15, 30 ngày', () {
      expect(MockWordApi.intervalDays(0), 1);
      expect(MockWordApi.intervalDays(1), 1);
      expect(MockWordApi.intervalDays(2), 2);
      expect(MockWordApi.intervalDays(3), 4);
      expect(MockWordApi.intervalDays(4), 7);
      expect(MockWordApi.intervalDays(5), 15);
      expect(MockWordApi.intervalDays(6), 30);
      expect(MockWordApi.intervalDays(9), 30, reason: 'quá 6 lần thì giữ 30 ngày');
    });

    test('tăng reviewCount và đẩy nextReview theo đúng khoảng cách', () async {
      final created = await api.createWord(
        const WordDraft(
          english: 'lucid',
          values: [WordValue(vietnamese: 'trong sáng')],
        ),
      );
      expect(created.reviewCount, 0);

      await api.confirmReview([created.id]);

      final after = (await api.fetchWords()).firstWhere(
        (word) => word.id == created.id,
      );
      expect(after.reviewCount, 1);
      expect(after.nextReview, isNotNull);
      final days = after.nextReview!.difference(DateTime.now()).inHours / 24;
      expect(days, closeTo(1, 0.1), reason: 'lần ôn đầu giãn 1 ngày');
    });

    test('danh sách rỗng thì trả 400', () async {
      final error = await captureError(() => api.confirmReview(const []));
      expect(error.statusCode, 400);
    });

    test('có wordId không thuộc người dùng thì trả 403', () async {
      final error = await captureError(() => api.confirmReview(const [1, 999]));
      expect(error.statusCode, 403);
    });
  });
}
