/// Khung tham chiếu CEFR của một từ — cột `words.level`.
enum Level {
  a1('A1'),
  a2('A2'),
  b1('B1'),
  b2('B2'),
  c1('C1'),
  c2('C2');

  const Level(this.wire);

  /// Giá trị backend trả về và nhận vào, ví dụ `"A1"`.
  final String wire;

  static Level? tryParse(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim().toUpperCase();
    for (final level in Level.values) {
      if (level.wire == value) return level;
    }
    return null;
  }
}

/// Từ loại — cột `word_values.part_of_speech`.
///
/// Backend khai báo `@Enumerated(EnumType.STRING)` nên JSON đi qua Jackson là
/// **tên enum viết hoa** (`"NOUN"`), còn dữ liệu trong MySQL lại là chữ thường
/// (`"noun"`). Ở đây giữ cả hai để đọc/ghi đều đúng.
enum PartOfSpeech {
  noun('noun', 'NOUN', 'Danh từ'),
  verb('verb', 'VERB', 'Động từ'),
  adjective('adjective', 'ADJECTIVE', 'Tính từ'),
  adverb('adverb', 'ADVERB', 'Trạng từ'),
  preposition('preposition', 'PREPOSITION', 'Giới từ'),
  conjunction('conjunction', 'CONJUNCTION', 'Liên từ'),
  pronoun('pronoun', 'PRONOUN', 'Đại từ'),
  interjection('interjection', 'INTERJECTION', 'Thán từ');

  const PartOfSpeech(this.dbValue, this.apiValue, this.label);

  /// Giá trị trong cột `part_of_speech`.
  final String dbValue;

  /// Giá trị gửi/nhận qua JSON.
  final String apiValue;

  /// Nhãn tiếng Việt hiển thị trên giao diện.
  final String label;

  static PartOfSpeech? tryParse(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim().toLowerCase().replaceAll('-', '_');
    for (final item in PartOfSpeech.values) {
      if (item.dbValue == value || item.apiValue.toLowerCase() == value) {
        return item;
      }
    }
    return null;
  }
}
