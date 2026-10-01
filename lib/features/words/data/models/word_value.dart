import '../json_utils.dart';
import 'enums.dart';

/// Một nghĩa của từ — bảng `word_values`.
class WordValue {
  const WordValue({
    this.id,
    required this.vietnamese,
    this.example,
    this.exampleTranslation,
    this.pronunciation,
    this.partOfSpeech,
  });

  final int? id;
  final String vietnamese;
  final String? example;
  final String? exampleTranslation;
  final String? pronunciation;
  final PartOfSpeech? partOfSpeech;

  factory WordValue.fromJson(Map<String, dynamic> json) => WordValue(
    id: asInt(json['id']),
    vietnamese: asString(json['vietnamese']),
    example: asStringOrNull(json['example']),
    exampleTranslation: asStringOrNull(json['exampleTranslation']),
    pronunciation: asStringOrNull(json['pronunciation']),
    partOfSpeech: PartOfSpeech.tryParse(json['partOfSpeech']),
  );

  /// Payload gửi lên backend. Khi tạo/sửa từ thì không gửi `id` của nghĩa:
  /// backend tự xoá và ghi lại danh sách `word_values` của từ đó.
  Map<String, dynamic> toJson({bool includeId = false}) => {
    if (includeId && id != null) 'id': id,
    'vietnamese': vietnamese,
    'example': example,
    'exampleTranslation': exampleTranslation,
    'pronunciation': pronunciation,
    'partOfSpeech': partOfSpeech?.apiValue,
  };

  /// Dòng bị bỏ trống trong form thì không gửi lên.
  bool get isBlank =>
      vietnamese.trim().isEmpty &&
      (example ?? '').trim().isEmpty &&
      (exampleTranslation ?? '').trim().isEmpty &&
      (pronunciation ?? '').trim().isEmpty;
}
