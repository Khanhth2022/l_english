import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/word.dart';
import '../data/word_api.dart';

enum LoadStatus { idle, loading, success, failure }

/// State của màn hình "Sổ từ của tôi".
///
/// Tài liệu thiết kế: danh sách từ chỉ tải một lần, tab "Ôn tập" lọc lại trên
/// chính dữ liệu đã tải (`next_review <= now`) nên không có API riêng.
class WordListController extends ChangeNotifier {
  WordListController(this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WordApi _api;
  final DateTime Function() _clock;

  LoadStatus status = LoadStatus.idle;
  String? errorMessage;
  String query = '';

  /// `true` khi tab đang xem là "Ôn tập".
  bool onlyDue = false;

  /// Đang gửi xác nhận ôn tập lên backend.
  bool submitting = false;

  List<Word> _words = const [];
  final Set<int> _selected = {};

  List<Word> get words => UnmodifiableListView(_words);

  /// Danh sách hiển thị theo tab và từ khoá tìm kiếm hiện tại.
  List<Word> get visibleWords {
    final keyword = query.trim().toLowerCase();
    final now = _clock();
    return _words.where((word) {
      if (onlyDue && !word.isDue(now)) return false;
      if (keyword.isEmpty) return true;
      if (word.english.toLowerCase().contains(keyword)) return true;
      return word.values.any(
        (value) => value.vietnamese.toLowerCase().contains(keyword),
      );
    }).toList();
  }

  /// Số từ đang đến hạn ôn (hiện trên nhãn tab "Ôn tập").
  int get dueCount {
    final now = _clock();
    return _words.where((word) => word.isDue(now)).length;
  }

  int get selectedCount => _selected.length;

  bool isSelected(int id) => _selected.contains(id);

  Future<void> load() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      _words = await _api.fetchWords();
      // Bỏ chọn những từ đã bị xoá ở nơi khác.
      _selected.removeWhere((id) => !_words.any((word) => word.id == id));
      status = LoadStatus.success;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = LoadStatus.failure;
    } catch (error) {
      errorMessage = 'Không tải được danh sách từ ($error).';
      status = LoadStatus.failure;
    }
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == query) return;
    query = value;
    notifyListeners();
  }

  void setOnlyDue(bool value) {
    if (value == onlyDue) return;
    onlyDue = value;
    if (!value) _selected.clear();
    notifyListeners();
  }

  void toggleSelected(int id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  /// Xoá một từ. Trả về thông báo lỗi để màn hình hiển thị, `null` nếu thành công.
  Future<String?> deleteWord(Word word) async {
    try {
      await _api.deleteWord(word.id);
      _words = _words.where((item) => item.id != word.id).toList();
      _selected.remove(word.id);
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  /// Ghi nhận đã ôn các từ đang được chọn rồi tải lại danh sách để thấy
  /// `reviewCount` và `nextReview` mới.
  Future<String?> confirmReview() async {
    if (_selected.isEmpty) return 'Chưa chọn từ nào để xác nhận ôn tập.';
    submitting = true;
    notifyListeners();
    try {
      await _api.confirmReview(_selected.toList());
      _selected.clear();
      await load();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
