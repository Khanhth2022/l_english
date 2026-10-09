import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/token_store.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/mock_auth_api.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/auth/ui/auth_screen.dart';
import 'features/home/main_screen.dart';
import 'features/phrases/data/mock_phrase_api.dart';
import 'features/phrases/data/phrase_api.dart';
import 'features/phrases/state/phrase_list_controller.dart';
import 'features/words/data/word_api.dart';
import 'features/words/state/word_list_controller.dart';

/// Ứng dụng LEnglish hiện đại, bám sát tài liệu thiết kế.
class LEnglishApp extends StatelessWidget {
  const LEnglishApp({
    super.key,
    required this.tokenStore,
    required this.wordApi,
    this.authApi,
    this.phraseApi,
  });

  final TokenStore tokenStore;
  final WordApi wordApi;
  final AuthApi? authApi;
  final PhraseApi? phraseApi;

  @override
  Widget build(BuildContext context) {
    final effectiveAuthApi = authApi ?? MockAuthApi();
    final effectivePhraseApi = phraseApi ?? MockPhraseApi();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TokenStore>.value(value: tokenStore),
        Provider<WordApi>.value(value: wordApi),
        Provider<AuthApi>.value(value: effectiveAuthApi),
        Provider<PhraseApi>.value(value: effectivePhraseApi),
        ChangeNotifierProvider<AuthController>(
          create: (ctx) => AuthController(
            api: effectiveAuthApi,
            tokenStore: tokenStore,
          ),
        ),
        ChangeNotifierProvider<WordListController>(
          create: (ctx) => WordListController(wordApi)..load(),
        ),
        ChangeNotifierProvider<PhraseListController>(
          create: (ctx) => PhraseListController(effectivePhraseApi)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'LEnglish',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Consumer<TokenStore>(
          builder: (context, store, _) {
            if (store.hasSession) {
              return const MainScreen();
            }
            return const AuthScreen();
          },
        ),
      ),
    );
  }
}
