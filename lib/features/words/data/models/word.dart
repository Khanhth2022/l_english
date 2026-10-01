import '../json_utils.dart';
import 'enums.dart';
import 'word_value.dart';

/// Một từ trong sổ từ — bảng `words` kèm danh sách nghĩa (`word_values`).
class Word {
  const Word({
    required this.id,
    required this.english,
    this.level,
    this.reviewCount = 0,
    this.nextReview,
    this.createdAt,
    this.updatedAt,
    this.values = const [],
  });

  final int id;
  final String english;
  final Level? level;

  /// Số lần đã xác nhận ôn tập.
  final int reviewCount;

  /// Mốc ôn lại kế tiếp; `null` nghĩa là từ mới, chưa từng ôn.
  final DateTime? nextReview;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<WordValue> values;

  /// Từ đang đến hạn ôn.
  ///
  /// Tài liệu thiết kế: tab Ôn tập **lọc ở phía client** theo `next_review <= now`
  /// (không có API riêng cho danh sách cần ôn), nên luật này nằm ở model.
  bool isDue(DateTime now) {
    final due = nextReview;
    return due == null || !due.isAfter(now);
  }

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    id: asInt(json['id']) ?? 0,
    english: asString(json['english']),
    level: Level.tryParse(json['level']),
    reviewCount: asInt(json['reviewCount']) ?? 0,
    nextReview: asDateTime(json['nextReview']),
    createdAt: asDateTime(json['createdAt']),
    updatedAt: asDateTime(json['updatedAt']),
    values: asMapList(json['values']).map(WordValue.fromJson).toList(),
  );

  @override
  String toString() => 'Word($id, $english)';
}
