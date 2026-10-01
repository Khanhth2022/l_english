import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/status_views.dart';
import '../data/models/word.dart';
import '../data/word_api.dart';
import '../state/word_list_controller.dart';
import 'connection_settings_screen.dart';
import 'widgets/word_card.dart';
import 'word_form_screen.dart';

/// Màn hình "Sổ từ của tôi" — chức năng Xem / Sửa / Xoá từ và Xác nhận ôn tập.
class WordListScreen extends StatelessWidget {
  const WordListScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    context.read<WordListController>().setOnlyDue(_tabs.index == 1);
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
          PopupMenuButton<String>(
            tooltip: 'Khác',
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConnectionSettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: controller.setQuery,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm theo từ tiếng Anh hoặc nghĩa tiếng Việt',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: controller.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xoá tìm kiếm',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          controller.setQuery('');
                        },
                      ),
              ),
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
        onPressed: () => _openForm(context, controller, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm từ'),
      );
    }
    if (controller.selectedCount == 0) return null;
    return FloatingActionButton.extended(
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
