import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/auth/secure_token_store.dart';
import 'core/auth/token_store.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/mock_auth_api.dart';
import 'features/auth/data/remote_auth_api.dart';
import 'features/phrases/data/mock_phrase_api.dart';
import 'features/phrases/data/phrase_api.dart';
import 'features/phrases/data/remote_phrase_api.dart';
import 'features/users/data/mock_user_api.dart';
import 'features/users/data/remote_user_api.dart';
import 'features/users/data/user_api.dart';
import 'features/words/data/mock_word_api.dart';
import 'features/words/data/remote_word_api.dart';
import 'features/words/data/word_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Token được mã hoá trong Keychain/EncryptedSharedPreferences và khôi phục
  // lại trước khi dựng giao diện để giữ phiên qua các lần mở ứng dụng.
  final tokenStore = SecureTokenStore(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
  await tokenStore.restore();

  final apiClient = createApiClient(tokenStore);

  // Giữ tham chiếu tới mock auth để mock hồ sơ đọc lại được tên đã lưu lúc đăng ký.
  final MockAuthApi? mockAuthApi =
      AppConfig.useMockApi ? MockAuthApi() : null;
  final AuthApi authApi = mockAuthApi ?? RemoteAuthApi(apiClient);

  if (AppConfig.useMockApi && !tokenStore.hasSession) {
    // Khởi tạo phiên thử nghiệm mặc định để người dùng khám phá ngay ứng dụng.
    // Đăng nhập thật qua mock (thay vì tự đặt token giả) để mock biết tài khoản
    // đang dùng — nhờ đó Đổi mật khẩu hoạt động ngay từ phiên demo đầu tiên.
    final demo = await authApi.login('user1', 'password123');
    await tokenStore.save(
      TokenPair(
        accessToken: demo.accessToken,
        refreshToken: demo.refreshToken,
      ),
      username: 'user1',
    );
  }

  final WordApi wordApi = AppConfig.useMockApi
      ? MockWordApi()
      : RemoteWordApi(apiClient);

  final PhraseApi phraseApi = AppConfig.useMockApi
      ? MockPhraseApi()
      : RemotePhraseApi(apiClient);

  final UserApi userApi = mockAuthApi != null
      ? MockUserApi(
          usernameProvider: () => tokenStore.currentUsername,
          nameProvider: mockAuthApi.displayNameOf,
        )
      : RemoteUserApi(apiClient);

  runApp(
    LEnglishApp(
      tokenStore: tokenStore,
      authApi: authApi,
      wordApi: wordApi,
      phraseApi: phraseApi,
      userApi: userApi,
      dio: apiClient,
    ),
  );
}
