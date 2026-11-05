import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/safe_change_notifier.dart';
import '../data/models/phrase_models.dart';
import '../data/phrase_api.dart';

class PhraseFormController extends ChangeNotifier with SafeChangeNotifier {
  PhraseFormController(this._api);

  final PhraseApi _api;

  /// Tiêu đề người dùng đặt cho đoạn văn (không gửi cho AI, chỉ lưu để hiển thị).
  final TextEditingController titleController = TextEditingController();

  final TextEditingController textController = TextEditingController();

  /// Khớp Bean Validation của backend: `@Size(max = 255)`.
  static const int titleMaxLength = 255;

  bool isGrading = false;
  String? errorMessage;
  Phrase? lastGradedPhrase;

  int get characterCount => textController.text.trim().length;

  /// Tiêu đề thực sự gửi lên server: để trống thì dùng nhãn mặc định, vì backend
  /// từ chối `title` rỗng (`@NotBlank`).
  String get effectiveTitle {
    final title = titleController.text.trim();
    return title.isEmpty ? Phrase.untitledLabel : title;
  }

  Future<Phrase?> submitForGrading() async {
    final title = titleController.text.trim();
    final text = textController.text.trim();
    if (text.length < 10) {
      errorMessage = 'Vui lòng nhập tối thiểu 10 ký tự tiếng Anh.';
      notifyListeners();
      return null;
    }
    if (text.length > 5000) {
      errorMessage = 'Đoạn văn gửi lên quá dài (tối đa 5000 ký tự).';
      notifyListeners();
      return null;
    }
    if (title.length > titleMaxLength) {
      errorMessage = 'Tiêu đề tối đa $titleMaxLength ký tự.';
      notifyListeners();
      return null;
    }

    isGrading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.createPhrase(effectiveTitle, text);
      lastGradedPhrase = result;
      return result;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (e) {
      debugPrint('PhraseFormController: chấm điểm thất bại ($e).');
      errorMessage = 'Không chấm được đoạn văn. Vui lòng thử lại.';
      return null;
    } finally {
      isGrading = false;
      notifyListeners();
    }
  }

  void setText(String text) {
    textController.text = text;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    textController.dispose();
    super.dispose();
  }
}
