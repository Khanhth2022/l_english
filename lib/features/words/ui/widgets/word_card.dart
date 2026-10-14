import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../data/models/word.dart';

/// Thẻ hiển thị một từ trong danh sách.
///
/// Ở tab "Ôn tập" thẻ có thêm ô chọn ([showCheckbox]) để đánh dấu những từ
/// người dùng vừa ôn xong.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    this.now,
    this.showCheckbox = false,
    this.selected = false,
    this.onToggleSelected,
    this.onEdit,
    this.onDelete,
  });

  final Word word;
  final DateTime? now;
  final bool showCheckbox;
  final bool selected;
  final VoidCallback? onToggleSelected;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = now ?? DateTime.now();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppTheme.primaryBlue : AppTheme.borderLight,
          width: selected ? 1.6 : 1,
        ),
      ),
      color: selected ? AppTheme.primaryBlue.withValues(alpha: 0.04) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: showCheckbox ? onToggleSelected : onEdit,
        child: Padding(
          padding: EdgeInsets.fromLTRB(showCheckbox ? 6 : 16, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCheckbox)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Checkbox(
                    value: selected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (_) => onToggleSelected?.call(),
                  ),
                ),
              Expanded(child: _buildBody(context, theme, current)),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                  tooltip: 'Thao tác',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                            SizedBox(width: 10),
                            Text('Sửa từ'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                            SizedBox(width: 10),
                            Text('Xoá từ', style: TextStyle(color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, DateTime current) {
    final firstValue = word.values.isNotEmpty ? word.values.first : null;
    final pronunciation = firstValue?.pronunciation;
    final hasPronunciation =
        pronunciation != null && pronunciation.trim().isNotEmpty;
    final pos = firstValue?.partOfSpeech;
    final hasPos = pos != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                word.english,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (word.level != null) ...[
              const SizedBox(width: 8),
              _LevelChip(label: word.level!.wire),
            ],
          ],
        ),
        if (hasPronunciation || hasPos) ...[
          const SizedBox(height: 3),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              if (hasPronunciation)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.volume_up_outlined,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pronunciation,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              if (hasPos)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pos.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (word.values.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final value in word.values.take(2)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• ${value.vietnamese}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMain,
                  height: 1.35,
                ),
              ),
            ),
            if (value.example != null && value.example!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 4),
                child: Text(
                  '"${value.example}"',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textMuted,
                    height: 1.3,
                  ),
                ),
              ),
          ],
          if (word.values.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '… và ${word.values.length - 2} nghĩa khác',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: word.reviewCount == 0
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    word.reviewCount == 0
                        ? Icons.auto_awesome
                        : Icons.history_rounded,
                    size: 13,
                    color: word.reviewCount == 0
                        ? const Color(0xFFD97706)
                        : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    word.reviewCount == 0 ? 'Từ mới' : 'Đã ôn ${word.reviewCount} lần',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: word.reviewCount == 0
                          ? const Color(0xFF92400E)
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatDueLabel(word.nextReview, current),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final upper = label.toUpperCase();
    Color bg;
    Color fg;
    Color border;

    if (upper.startsWith('A')) {
      bg = AppTheme.successBg;
      fg = AppTheme.successGreen;
      border = AppTheme.successGreen.withValues(alpha: 0.25);
    } else if (upper.startsWith('B')) {
      bg = const Color(0xFFEFF6FF);
      fg = AppTheme.primaryBlue;
      border = AppTheme.primaryBlue.withValues(alpha: 0.25);
    } else {
      bg = AppTheme.aiBg;
      fg = AppTheme.aiPurple;
      border = AppTheme.aiPurple.withValues(alpha: 0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
