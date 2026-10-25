import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/status_views.dart';
import '../data/models/word.dart';
import '../data/word_api.dart';
import '../state/word_list_controller.dart';
import 'connection_settings_screen.dart';
import 'widgets/word_card.dart';
import 'review_quiz_screen.dart';
import 'word_form_screen.dart';
import 'topic_words_screen.dart';

/// Màn hình "Sổ từ của tôi" — chức năng Xem / Sửa / Xoá từ và Xác nhận ôn tập.
class WordListScreen extends StatelessWidget {
  const WordListScreen({super.key});

  /// Thông báo chuyển tab (0: Tất cả, 1: Ôn tập) được kích hoạt từ Widget Android hoặc deep link.
  static final ValueNotifier<int> selectedTabNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    WordListController? existing;
    try {
      existing = Provider.of<WordListController>(context, listen: false);
    } catch (_) {
      existing = null;
    }

    if (existing != null) {
      return const _WordListView();
    }

    return ChangeNotifierProvider(
      create: (ctx) =>
          WordListController(ctx.read<WordApi>())..load(),
      child: const _WordListView(),
    );
  }
}

class _WordListView extends StatefulWidget {
  const _WordListView();

  @override
  State<_WordListView> createState() => _WordListViewState();
}

class _WordListViewState extends State<_WordListView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTabChanged);
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WordListScreen.selectedTabNotifier.addListener(_onExternalTabChange);
    final target = WordListScreen.selectedTabNotifier.value;
    if (target != 0) {
      WordListScreen.selectedTabNotifier.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && target < _tabs.length) {
          if (_tabs.index != target) {
            _tabs.animateTo(target);
          }
          if (target == 1) {
            _startReviewQuiz();
          }
        }
      });
    }
  }

  void _onExternalTabChange() {
    if (!mounted) return;
    final target = WordListScreen.selectedTabNotifier.value;
    if (target != 0) {
      WordListScreen.selectedTabNotifier.value = 0;
      if (_tabs.index != target && target < _tabs.length) {
        _tabs.animateTo(target);
      }
      if (target == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startReviewQuiz();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WordListScreen.selectedTabNotifier.removeListener(_onExternalTabChange);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    context.read<WordListController>().setOnlyDue(_tabs.index == 1);
  }

  Future<void> _startReviewQuiz() async {
    final controller = context.read<WordListController>();
    if (controller.status == LoadStatus.loading || controller.status == LoadStatus.idle) {
      int waitMs = 0;
      while (mounted && controller.status == LoadStatus.loading && waitMs < 3000) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        waitMs += 100;
      }
    }
    if (!mounted) return;

    final now = DateTime.now();
    final dueWords = controller.words.where((w) => w.isDue(now)).toList();
    if (dueWords.isEmpty) {
      _showMessage(context, 'Tuyệt vời! Bạn không còn từ nào cần ôn tập hôm nay.');
      return;
    }

    final navigator = Navigator.of(context);
    final changed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewQuizScreen(
          words: dueWords,
          allWords: controller.words,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      await controller.load();
    }
  }

  Widget _buildReviewQuizBanner(BuildContext context, WordListController controller) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Có ${controller.dueCount} từ cần ôn tập!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Luyện trắc nghiệm để củng cố trí nhớ dài hạn.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _startReviewQuiz(),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTopicWords(
    BuildContext context,
    WordListController controller,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TopicWordsScreen(),
      ),
    );
    if (changed == true && mounted) {
      await controller.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WordListController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ từ của tôi'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: controller.status == LoadStatus.loading
                ? null
                : controller.load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Thêm từ theo chủ đề (AI)',
            icon: const Icon(Icons.auto_awesome, color: AppTheme.aiPurple),
            onPressed: () => _openTopicWords(context, controller),
          ),
          PopupMenuButton<String>(
            tooltip: 'Khác',
            onSelected: (value) async {
              if (value == 'topic') {
                await _openTopicWords(context, controller);
              } else if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConnectionSettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'topic',
                child: Text('Thêm từ theo chủ đề (AI)'),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text('Cấu hình kết nối'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Tất cả'),
            Tab(text: 'Ôn tập (${controller.dueCount})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: _searchController,
              onChanged: controller.setQuery,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm theo từ tiếng Anh hoặc nghĩa tiếng Việt',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.8),
                ),
                suffixIcon: controller.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xoá tìm kiếm',
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          controller.setQuery('');
                        },
                      ),
              ),
            ),
          ),
          if (controller.onlyDue && controller.dueCount > 0)
            _buildReviewQuizBanner(context, controller),
          if (controller.onlyDue && controller.dueCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Đã chọn ${controller.selectedCount}/${controller.dueCount}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      final allSelected =
                          controller.selectedCount == controller.visibleWords.length;
                      for (final word in controller.visibleWords) {
                        final isSel = controller.isSelected(word.id);
                        if (allSelected && isSel) {
                          controller.toggleSelected(word.id);
                        } else if (!allSelected && !isSel) {
                          controller.toggleSelected(word.id);
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.selectedCount == controller.visibleWords.length
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                            size: 15,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            controller.selectedCount == controller.visibleWords.length
                                ? 'Bỏ chọn'
                                : 'Chọn tất cả',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildContent(context, controller)),
        ],
      ),
      floatingActionButton: _buildFab(context, controller),
    );
  }

  Widget _buildContent(BuildContext context, WordListController controller) {
    switch (controller.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(message: 'Đang tải danh sách từ…');
      case LoadStatus.failure:
        return ErrorView(
          message: controller.errorMessage ?? 'Không tải được danh sách từ.',
          onRetry: controller.load,
        );
      case LoadStatus.success:
        break;
    }

    final words = controller.visibleWords;
    if (words.isEmpty) return _buildEmpty(controller);

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return WordCard(
            word: word,
            showCheckbox: controller.onlyDue,
            selected: controller.isSelected(word.id),
            onToggleSelected: () => controller.toggleSelected(word.id),
            onEdit: () => _openForm(context, controller, word),
            onDelete: () => _confirmDelete(context, controller, word),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(WordListController controller) {
    if (controller.onlyDue) {
      return const EmptyView(
        icon: Icons.task_alt,
        title: 'Không có từ nào đến hạn ôn',
        description:
            'Từ mới thêm và từ đã tới lịch ôn sẽ xuất hiện ở đây. '
            'Sang tab "Tất cả" để xem toàn bộ sổ từ.',
      );
    }
    if (controller.query.trim().isNotEmpty) {
      return const EmptyView(
        icon: Icons.search_off,
        title: 'Không tìm thấy từ phù hợp',
        description: 'Thử từ khoá khác, hoặc xoá ô tìm kiếm.',
      );
    }
    return EmptyView(
      icon: Icons.menu_book_outlined,
      title: 'Sổ từ đang trống',
      description: 'Thêm từ đầu tiên để bắt đầu học và ôn tập.',
      action: FilledButton.icon(
        onPressed: () => _openForm(context, controller, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm từ'),
      ),
    );
  }

  Widget? _buildFab(BuildContext context, WordListController controller) {
    if (!controller.onlyDue) {
      return FloatingActionButton.extended(
        heroTag: 'word_list_add_fab',
        onPressed: () => _openForm(context, controller, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm từ'),
      );
    }
    if (controller.selectedCount > 0) {
      return FloatingActionButton.extended(
        heroTag: 'word_list_review_fab',
        onPressed: controller.submitting
            ? null
            : () => _confirmReview(context, controller),
        icon: controller.submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.done_all),
        label: Text('Đã ôn ${controller.selectedCount} từ'),
      );
    }
    if (controller.dueCount > 0) {
      return FloatingActionButton.extended(
        heroTag: 'word_list_quiz_fab',
        backgroundColor: AppTheme.aiPurple,
        foregroundColor: Colors.white,
        onPressed: () => _startReviewQuiz(),
        icon: const Icon(Icons.quiz_rounded),
        label: Text('Ôn tập (${controller.dueCount})'),
      );
    }
    return null;
  }

  Future<void> _openForm(
    BuildContext context,
    WordListController controller,
    Word? word,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WordFormScreen(existing: word)),
    );
    if (changed != true) return;
    await controller.load();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WordListController controller,
    Word word,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xoá từ "${word.english}"?'),
        content: const Text('Từ cùng toàn bộ nghĩa của nó sẽ bị xoá khỏi sổ từ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await controller.deleteWord(word);
    if (!context.mounted) return;
    _showMessage(
      context,
      error ?? 'Đã xoá từ "${word.english}".',
      isError: error != null,
    );
  }

  Future<void> _confirmReview(
    BuildContext context,
    WordListController controller,
  ) async {
    final count = controller.selectedCount;
    final error = await controller.confirmReview();
    if (!context.mounted) return;
    _showMessage(
      context,
      error ?? 'Đã ghi nhận ôn tập $count từ, lịch ôn đã được giãn ra.',
      isError: error != null,
    );
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }
}
