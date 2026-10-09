import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/safe_change_notifier.dart';
import '../data/models/phrase_models.dart';
import '../data/phrase_api.dart';

enum PhraseListStatus { idle, loading, success, failure }

class PhraseListController extends ChangeNotifier with SafeChangeNotifier {
  PhraseListController(this._api);

  final PhraseApi _api;

  PhraseListStatus status = PhraseListStatus.idle;
  String? errorMessage;
  List<Phrase> _phrases = const [];

  List<Phrase> get phrases => UnmodifiableListView(_phrases);

  double get averageScore {
    if (_phrases.isEmpty) return 0.0;
    final total = _phrases.fold<int>(0, (sum, p) => sum + p.score);
    return total / _phrases.length;
  }

  Future<void> load() async {
    status = PhraseListStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      _phrases = await _api.fetchPhrases();
      status = PhraseListStatus.success;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = PhraseListStatus.failure;
    } catch (e) {
      errorMessage = 'Không tải được danh sách đoạn văn ($e).';
      status = PhraseListStatus.failure;
    }
    notifyListeners();
  }

  Future<String?> deletePhrase(Phrase phrase) async {
    try {
      await _api.deletePhrase(phrase.id);
      _phrases = _phrases.where((item) => item.id != phrase.id).toList();
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (e) {
      return 'Lỗi khi xóa ($e).';
    }
  }

  void addOrUpdatePhrase(Phrase phrase) {
    _phrases = [phrase, ..._phrases.where((p) => p.id != phrase.id)];
    notifyListeners();
  }
}
