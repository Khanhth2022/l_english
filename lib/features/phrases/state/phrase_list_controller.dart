import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/safe_change_notifier.dart';
import '../data/models/phrase_models.dart';
import '../data/phrase_api.dart';

enum PhraseListStatus { idle, loading, success, failure }

class PhraseListController extends ChangeNotifier with SafeChangeNotifier {
  PhraseListController(this._api, {TokenStore? tokenStore})
    : _tokenStore = tokenStore,
      _lastLoggedIn = tokenStore?.hasSession ?? true {
    _tokenStore?.addListener(_onSessionChanged);
  }

  final PhraseApi _api;
  final TokenStore? _tokenStore;
  bool _lastLoggedIn;

  PhraseListStatus status = PhraseListStatus.idle;
  String? errorMessage;
  List<Phrase> _phrases = const [];

  List<Phrase> get phrases => UnmodifiableListView(_phrases);

  double get averageScore {
    if (_phrases.isEmpty) return 0.0;
    final total = _phrases.fold<int>(0, (sum, p) => sum + p.score);
    return total / _phrases.length;
  }

  void _onSessionChanged() {
    final loggedIn = _tokenStore!.hasSession;
    if (loggedIn == _lastLoggedIn) return;
    _lastLoggedIn = loggedIn;
    if (loggedIn) {
      load();
    } else {
      reset();
    }
  }

  /// Xoá sạch dữ liệu của phiên trước khi đăng xuất.
  void reset() {
    _phrases = const [];
    status = PhraseListStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    status = PhraseListStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final phrases = await _api.fetchPhrases();
      if (_tokenStore?.hasSession == false) return;
      _phrases = phrases;
      status = PhraseListStatus.success;
    } on ApiException catch (error) {
      if (_tokenStore?.hasSession == false) return;
      errorMessage = error.message;
      status = PhraseListStatus.failure;
    } catch (e) {
      if (_tokenStore?.hasSession == false) return;
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

  @override
  void dispose() {
    _tokenStore?.removeListener(_onSessionChanged);
    super.dispose();
  }
}
