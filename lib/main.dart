import 'package:flutter/material.dart';

import 'app.dart';
import 'core/auth/token_store.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/mock_auth_api.dart';
import 'features/auth/data/remote_auth_api.dart';
import 'features/phrases/data/mock_phrase_api.dart';
import 'features/phrases/data/phrase_api.dart';
import 'features/phrases/data/remote_phrase_api.dart';
import 'features/words/data/mock_word_api.dart';
import 'features/words/data/remote_word_api.dart';
import 'features/words/data/word_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStore = InMemoryTokenStore();

  if (AppConfig.useMockApi) {
    // Khởi tạo phiên thử nghiệm mặc định để người dùng khám phá ngay ứng dụng
    await tokenStore.save(
      const TokenPair(
        accessToken: 'mock_jwt_access_user1_init',
        refreshToken: 'mock_jwt_refresh_user1_init',
      ),
      username: 'user1',
    );
  }

  final apiClient = createApiClient(tokenStore);

  final AuthApi authApi = AppConfig.useMockApi
      ? MockAuthApi()
      : RemoteAuthApi(apiClient);

  final WordApi wordApi = AppConfig.useMockApi
      ? MockWordApi()
      : RemoteWordApi(apiClient);

  final PhraseApi phraseApi = AppConfig.useMockApi
      ? MockPhraseApi()
      : RemotePhraseApi(apiClient);

  runApp(
    LEnglishApp(
      tokenStore: tokenStore,
      authApi: authApi,
      wordApi: wordApi,
      phraseApi: phraseApi,
    ),
  );
}
