import '../../../words/data/json_utils.dart';

/// Một lỗi ngữ pháp trong đoạn văn — bảng `grammar_errors`.
class GrammarError {
  const GrammarError({
    this.id,
    this.incorrect,
    this.correction,
    required this.explanation,
  });

  final int? id;
  final String? incorrect;
  final String? correction;
  final String explanation;

  factory GrammarError.fromJson(Map<String, dynamic> json) => GrammarError(
        id: asInt(json['id']),
        incorrect: asStringOrNull(json['incorrect']),
        correction: asStringOrNull(json['correction']),
        explanation: asString(json['explanation']),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'incorrect': incorrect,
        'correction': correction,
        'explanation': explanation,
      };
}

/// Một đoạn văn đã được AI chấm điểm — bảng `phrases`.
class Phrase {
  const Phrase({
    required this.id,
    required this.text,
    required this.correctedText,
    required this.score,
    this.createdAt,
    this.updatedAt,
    this.errors = const [],
  });

  final int id;
  final String text;
  final String correctedText;

  /// Điểm số từ 0 đến 10 (do AI chấm).
  final int score;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<GrammarError> errors;

  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
        id: asInt(json['id']) ?? 0,
        text: asString(json['text']),
        correctedText: asString(json['correctedText']),
        score: asInt(json['score']) ?? 0,
        createdAt: asDateTime(json['createdAt']),
        updatedAt: asDateTime(json['updatedAt']),
        errors: asMapList(json['errors']).map(GrammarError.fromJson).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'correctedText': correctedText,
        'score': score,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'errors': errors.map((e) => e.toJson()).toList(),
      };
}
