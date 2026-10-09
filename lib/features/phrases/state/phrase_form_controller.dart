import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/phrase_models.dart';
import '../data/phrase_api.dart';

class PhraseFormController extends ChangeNotifier {
  PhraseFormController(this._api);

  final PhraseApi _api;
  final TextEditingController textController = TextEditingController();

  bool isGrading = false;
  String? errorMessage;
  Phrase? lastGradedPhrase;

  int get characterCount => textController.text.trim().length;

  Future<Phrase?> submitForGrading() async {
    final text = textController.text.trim();
    if (text.length < 10) {
      errorMessage = 'Vui lòng nhập tối thiểu 10 ký tự tiếng Anh.';
      notifyListeners();
      return null;
    }

    isGrading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.createPhrase(text);
      lastGradedPhrase = result;
      return result;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (e) {
      errorMessage = 'Lỗi không xác định khi chấm điểm ($e).';
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
    textController.dispose();
    super.dispose();
  }
}
