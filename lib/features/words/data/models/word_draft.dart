import 'enums.dart';
import 'word.dart';
import 'word_value.dart';

/// Dữ liệu form Thêm/Sửa từ gửi lên `POST /api/words` và `PUT /api/words/{id}`.
class WordDraft {
  const WordDraft({required this.english, this.level, this.values = const []});

  final String english;
  final Level? level;
  final List<WordValue> values;

  /// Đổ dữ liệu của một từ đã có vào form Sửa.
  factory WordDraft.fromWord(Word word) => WordDraft(
    english: word.english,
    level: word.level,
    values: word.values,
  );

  Map<String, dynamic> toJson() => {
    'english': english,
    'level': level?.wire,
    'values': values.map((value) => value.toJson()).toList(),
  };
}
