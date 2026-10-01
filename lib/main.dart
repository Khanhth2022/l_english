import 'package:flutter/material.dart';

import 'app.dart';
import 'core/auth/token_store.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/words/data/mock_word_api.dart';
import 'features/words/data/remote_word_api.dart';
import 'features/words/data/word_api.dart';

void main() {
  // Nhánh feature/auth sẽ thay bằng bản lưu token an toàn trong Keystore.
  final tokenStore = InMemoryTokenStore();

  final WordApi wordApi = AppConfig.useMockApi
      ? MockWordApi()
      : RemoteWordApi(createApiClient(tokenStore));

  runApp(LEnglishApp(tokenStore: tokenStore, wordApi: wordApi));
}
