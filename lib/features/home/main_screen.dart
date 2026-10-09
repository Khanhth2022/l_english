import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../android_tools/ui/android_features_screen.dart';
import '../auth/ui/profile_screen.dart';
import '../phrases/ui/phrase_list_screen.dart';
import '../words/ui/word_list_screen.dart';

/// Màn hình điều hướng chính của ứng dụng LEnglish (Modern Navigation Bar).
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    WordListScreen(),
    PhraseListScreen(),
    AndroidFeaturesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: AppTheme.primaryBlue),
            label: 'Từ vựng',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue),
            label: 'Chấm bài',
          ),
          NavigationDestination(
            icon: Icon(Icons.android_outlined),
            selectedIcon: Icon(Icons.android_rounded, color: AppTheme.primaryBlue),
            label: 'Tiện ích',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryBlue),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
