import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/safe_change_notifier.dart';
import '../data/models/enums.dart';
import '../data/models/word.dart';
import '../data/models/word_draft.dart';
import '../data/models/word_value.dart';
import '../data/word_api.dart';

/// Một dòng nghĩa trong form Thêm/Sửa từ, giữ sẵn các [TextEditingController]
/// để không bị mất nội dung khi giao diện vẽ lại.
class WordValueRow {
  WordValueRow({
    this.id,
    String vietnamese = '',
    String example = '',
    String exampleTranslation = '',
    String pronunciation = '',
    this.partOfSpeech,
  }) : vietnameseController = TextEditingController(text: vietnamese),
       exampleController = TextEditingController(text: example),
       exampleTranslationController = TextEditingController(
         text: exampleTranslation,
       ),
       pronunciationController = TextEditingController(text: pronunciation);

  factory WordValueRow.fromValue(WordValue value) => WordValueRow(
    id: value.id,
    vietnamese: value.vietnamese,
    example: value.example ?? '',
    exampleTranslation: value.exampleTranslation ?? '',
    pronunciation: value.pronunciation ?? '',
    partOfSpeech: value.partOfSpeech,
  );

  final int? id;
  final TextEditingController vietnameseController;
  final TextEditingController exampleController;
  final TextEditingController exampleTranslationController;
  final TextEditingController pronunciationController;
  PartOfSpeech? partOfSpeech;

  bool get isBlank =>
      vietnameseController.text.trim().isEmpty &&
      exampleController.text.trim().isEmpty &&
      exampleTranslationController.text.trim().isEmpty &&
      pronunciationController.text.trim().isEmpty;

  WordValue toValue() => WordValue(
    id: id,
    vietnamese: vietnameseController.text.trim(),
    example: _nullIfEmpty(exampleController.text),
    exampleTranslation: _nullIfEmpty(exampleTranslationController.text),
    pronunciation: _nullIfEmpty(pronunciationController.text),
    partOfSpeech: partOfSpeech,
  );

  void dispose() {
    vietnameseController.dispose();
    exampleController.dispose();
    exampleTranslationController.dispose();
    pronunciationController.dispose();
  }

  static String? _nullIfEmpty(String text) {
    final value = text.trim();
    return value.isEmpty ? null : value;
  }
}

/// State của màn hình Thêm/Sửa từ.
class WordFormController extends ChangeNotifier with SafeChangeNotifier {
  WordFormController({
    required this.api,
    Word? existing,
    String? initialEnglish,
  }) : _existing = existing {
    englishController.text =
        existing?.english ?? (initialEnglish?.trim() ?? '');
    level = existing?.level;
    rows = (existing == null || existing.values.isEmpty)
        ? [WordValueRow()]
        : existing.values.map(WordValueRow.fromValue).toList();

    // Ảnh chụp dữ liệu ban đầu để biết người dùng đã thay đổi gì chưa (ACT-6/7).
    _initialEnglish = englishController.text.trim();
    _initialLevel = level;
    _initialValues = _currentValues();
  }

  final WordApi api;
  final Word? _existing;

  late final String _initialEnglish;
  late final Level? _initialLevel;
  late final List<WordValue> _initialValues;

  final TextEditingController englishController = TextEditingController();
  Level? level;
  late List<WordValueRow> rows;

  bool generating = false;
  bool saving = false;
  String? notice;

  bool get isEditing => _existing != null;

  String get title => isEditing ? 'Sửa từ' : 'Thêm từ';

  /// Người dùng đã nhập/sửa gì so với dữ liệu ban đầu hay chưa.
  ///
  /// Dùng cho hộp thoại xác nhận thoát (ACT-6/7) và để bỏ qua hộp thoại
  /// "Thay thế nghĩa đã nhập?" khi form vẫn còn nguyên dữ liệu gốc.
  ///
  /// Các [TextEditingController] của từng dòng không phát thông báo thay đổi,
  /// nên đây là getter tính tại chỗ thay vì một cờ `dirty` cập nhật dần.
  bool get hasChanges {
    if (englishController.text.trim() != _initialEnglish) return true;
    if (level != _initialLevel) return true;

    final current = _currentValues();
    if (current.length != _initialValues.length) return true;
    for (var index = 0; index < current.length; index++) {
      if (!_sameValue(current[index], _initialValues[index])) return true;
    }
    return false;
  }

  /// Có ít nhất một nghĩa người dùng đã nhập (dùng để hỏi trước khi AI ghi đè).
  bool get hasEnteredValues => rows.any((row) => !row.isBlank);

  List<WordValue> _currentValues() =>
      rows.where((row) => !row.isBlank).map((row) => row.toValue()).toList();

  static bool _sameValue(WordValue a, WordValue b) =>
      a.vietnamese == b.vietnamese &&
      a.example == b.example &&
      a.exampleTranslation == b.exampleTranslation &&
      a.pronunciation == b.pronunciation &&
      a.partOfSpeech == b.partOfSpeech;

  void setLevel(Level? value) {
    level = value;
    notifyListeners();
  }

  void setPartOfSpeech(WordValueRow row, PartOfSpeech? value) {
    row.partOfSpeech = value;
    notifyListeners();
  }

  void addRow() {
    rows = [...rows, WordValueRow()];
    notifyListeners();
  }

  void removeRow(WordValueRow row) {
    if (rows.length <= 1) return; // luôn giữ lại ít nhất một dòng nghĩa
    rows = rows.where((item) => item != row).toList();
    row.dispose();
    notifyListeners();
  }

  /// Nhờ AI sinh nghĩa cho từ tiếng Anh đang nhập.
  /// Trả về thông báo lỗi, `null` nếu thành công.
  Future<String?> generateMeaning() async {
    final english = englishController.text.trim();
    if (english.isEmpty) {
      return 'Nhập từ tiếng Anh trước khi nhờ AI sinh nghĩa.';
    }

    generating = true;
    notice = null;
    notifyListeners();
    try {
      final generated = await api.generateMeaning(english);
      if (generated.values.isEmpty) {
        return 'Không sinh được nghĩa nào cho "$english".';
      }
      if (generated.level != null) {
        level = generated.level;
      }
      for (final row in rows) {
        row.dispose();
      }
      rows = generated.values.map(WordValueRow.fromValue).toList();
      notice = 'Đã điền ${generated.values.length} nghĩa cho "$english".';
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      debugPrint('WordFormController: sinh nghĩa thất bại ($error).');
      return 'Không sinh được nghĩa cho từ này. Vui lòng thử lại.';
    } finally {
      generating = false;
      notifyListeners();
    }
  }

  /// Lưu từ. Trả về thông báo lỗi, `null` nếu thành công.
  Future<String?> save() async {
    final english = englishController.text.trim();
    if (english.isEmpty) return 'Nhập từ tiếng Anh.';

    final values = rows
        .where((row) => !row.isBlank)
        .map((row) => row.toValue())
        .toList();
    if (values.isEmpty) return 'Cần ít nhất một nghĩa tiếng Việt.';
    if (values.any((value) => value.vietnamese.isEmpty)) {
      return 'Mỗi nghĩa cần có nội dung tiếng Việt.';
    }

    saving = true;
    notifyListeners();
    try {
      final draft = WordDraft(english: english, level: level, values: values);
      final existing = _existing;
      if (existing == null) {
        await api.createWord(draft);
      } else {
        await api.updateWord(existing.id, draft);
      }
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      debugPrint('WordFormController: lưu từ thất bại ($error).');
      return 'Không lưu được từ. Vui lòng thử lại.';
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    englishController.dispose();
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }
}
