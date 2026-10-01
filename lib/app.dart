import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/token_store.dart';
import 'features/words/data/word_api.dart';
import 'features/words/ui/word_list_screen.dart';

/// Ứng dụng L-english.
///
/// `tokenStore` và `wordApi` được tạo ở `main.dart` rồi truyền xuống để mọi
/// màn hình dùng chung một phiên đăng nhập và một nguồn dữ liệu.
class LEnglishApp extends StatelessWidget {
  const LEnglishApp({
    super.key,
    required this.tokenStore,
    required this.wordApi,
  });

  final TokenStore tokenStore;
  final WordApi wordApi;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // .value vì tokenStore do main.dart tạo và quản lý vòng đời.
        ChangeNotifierProvider<TokenStore>.value(value: tokenStore),
        Provider<WordApi>.value(value: wordApi),
      ],
      child: MaterialApp(
        title: 'L-english',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        ),
        home: const WordListScreen(),
      ),
    );
  }
}
