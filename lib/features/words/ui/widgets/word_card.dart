import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../data/models/word.dart';
import '../../data/models/word_value.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: showCheckbox ? onToggleSelected : onEdit,
        child: Padding(
          padding: EdgeInsets.fromLTRB(showCheckbox ? 4 : 16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCheckbox)
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelected?.call(),
                ),
              Expanded(child: _buildBody(context, theme, current)),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Thao tác',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Sửa từ')),
                    if (onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('Xoá từ')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, DateTime current) {
    final detail = _detailLine(word.values);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                word.english,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (word.level != null) ...[
              const SizedBox(width: 8),
              _LevelChip(label: word.level!.wire),
            ],
          ],
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
        if (word.values.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final value in word.values.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• ${value.vietnamese}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (word.values.length > 2)
            Text(
              '… và ${word.values.length - 2} nghĩa khác',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
        const SizedBox(height: 6),
        Text(
          '${word.reviewCount == 0 ? 'Từ mới' : 'Đã ôn ${word.reviewCount} lần'}'
          ' · ${formatDueLabel(word.nextReview, current)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// Dòng phụ: phiên âm và từ loại của nghĩa đầu tiên.
  String? _detailLine(List<WordValue> values) {
    if (values.isEmpty) return null;
    final first = values.first;
    final parts = <String>[
      if (first.pronunciation != null) first.pronunciation!,
      if (first.partOfSpeech != null) first.partOfSpeech!.label,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
