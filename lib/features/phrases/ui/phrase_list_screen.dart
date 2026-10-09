import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/status_views.dart';
import '../../../core/utils/date_format.dart';
import '../data/models/phrase_models.dart';
import '../state/phrase_list_controller.dart';
import 'phrase_form_screen.dart';
import 'widgets/phrase_detail_sheet.dart';

/// Màn hình danh sách đoạn văn đã chấm điểm (act-10, seq-10, act-13, seq-13).
class PhraseListScreen extends StatelessWidget {
  const PhraseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhraseListController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện viết & Chấm bài'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: controller.status == PhraseListStatus.loading ? null : controller.load,
          ),
        ],
      ),
      body: _buildBody(context, controller),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PhraseFormScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.aiPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Chấm đoạn văn mới'),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PhraseListController controller) {
    switch (controller.status) {
      case PhraseListStatus.idle:
      case PhraseListStatus.loading:
        return const LoadingView(message: 'Đang tải danh sách bài viết...');
      case PhraseListStatus.failure:
        return ErrorView(
          message: controller.errorMessage ?? 'Không thể tải danh sách bài viết.',
          onRetry: controller.load,
        );
      case PhraseListStatus.success:
        break;
    }

    final phrases = controller.phrases;
    if (phrases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.aiPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded, size: 40, color: AppTheme.aiPurple),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có bài viết nào',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy viết một câu hoặc đoạn văn để AI chấm điểm và chỉ ra các lỗi ngữ pháp cho bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PhraseFormScreen()),
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.aiPurple),
                icon: const Icon(Icons.add),
                label: const Text('Viết đoạn văn đầu tiên'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          // Thống kê tổng quan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng số bài đã chấm',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${phrases.length} đoạn văn',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Điểm TB: ${controller.averageScore.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Danh sách các bài
          ...phrases.map((phrase) => _buildPhraseCard(context, controller, phrase)),
        ],
      ),
    );
  }

  Widget _buildPhraseCard(
    BuildContext context,
    PhraseListController controller,
    Phrase phrase,
  ) {
    final scoreColor = phrase.score >= 8
        ? AppTheme.successGreen
        : phrase.score >= 5
            ? AppTheme.warningOrange
            : AppTheme.errorRed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => PhraseDetailSheet(phrase: phrase),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${phrase.score}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phrase.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMain,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: phrase.errors.isEmpty ? AppTheme.successBg : AppTheme.errorBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                phrase.errors.isEmpty
                                    ? 'Chuẩn ngữ pháp'
                                    : '${phrase.errors.length} lỗi cần sửa',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: phrase.errors.isEmpty ? AppTheme.successGreen : AppTheme.errorRed,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (phrase.createdAt != null)
                              Text(
                                formatDate(phrase.createdAt!),
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                    onSelected: (action) {
                      if (action == 'delete') {
                        _confirmDelete(context, controller, phrase);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                            SizedBox(width: 8),
                            Text('Xóa bài này', style: TextStyle(color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PhraseListController controller,
    Phrase phrase,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa đoạn văn này?'),
        content: const Text('Đoạn văn cùng kết quả chấm điểm của AI sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final error = await controller.deletePhrase(phrase);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Đã xóa đoạn văn thành công.'),
            backgroundColor: error != null ? AppTheme.errorRed : null,
          ),
        );
      }
    }
  }
}
