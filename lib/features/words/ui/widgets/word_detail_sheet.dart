import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../data/models/word.dart';
import '../../data/models/word_value.dart';

/// Modal xem chi tiết một từ ở dạng **chỉ đọc**.
///
/// Trước đây chạm vào thẻ từ là mở thẳng form Sửa từ, nên rất dễ sửa nhầm dữ
/// liệu khi người dùng chỉ muốn xem lại nghĩa (ACT-5). Việc chỉnh sửa đã có
/// mục "Sửa từ" trong menu thao tác của thẻ.
class WordDetailSheet extends StatelessWidget {
  const WordDetailSheet({super.key, required this.word, this.now});

  final Word word;

  /// Thời điểm dùng để tính nhãn "đến hạn" — truyền vào khi cần test cố định.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final current = now ?? DateTime.now();
    final dueNow = isDueForReview(word.nextReview, current);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            word.english,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                        if (word.level != null) ...[
                          const SizedBox(width: 8),
                          _LevelChip(label: word.level!.wire),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          label: formatDueLabel(word.nextReview, current),
                          foreground: dueNow
                              ? AppTheme.errorRed
                              : AppTheme.textMuted,
                          background: dueNow
                              ? AppTheme.errorBg
                              : const Color(0xFFF1F5F9),
                          border: dueNow
                              ? AppTheme.errorRed.withValues(alpha: 0.25)
                              : null,
                        ),
                        _InfoChip(
                          icon: word.reviewCount == 0
                              ? Icons.auto_awesome
                              : Icons.history_rounded,
                          label: word.reviewCount == 0
                              ? 'Từ mới'
                              : 'Đã ôn ${word.reviewCount} lần',
                          foreground: word.reviewCount == 0
                              ? const Color(0xFF92400E)
                              : AppTheme.textMuted,
                          background: word.reviewCount == 0
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Nghĩa của từ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (word.values.isEmpty)
                      const Text(
                        'Từ này chưa có nghĩa nào.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.textMuted,
                        ),
                      )
                    else
                      for (final (index, value) in word.values.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ValueCard(index: index, value: value),
                        ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đây là chế độ chỉ xem. Muốn sửa từ, chạm nút ⋮ '
                              'trên thẻ từ rồi chọn "Sửa từ".',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.index, required this.value});

  final int index;
  final WordValue value;

  @override
  Widget build(BuildContext context) {
    final example = value.example?.trim() ?? '';
    final exampleTranslation = value.exampleTranslation?.trim() ?? '';
    final pronunciation = value.pronunciation?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value.vietnamese,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMain,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (pronunciation.isNotEmpty || value.partOfSpeech != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (pronunciation.isNotEmpty)
                  Text(
                    pronunciation,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      color: AppTheme.textMuted,
                    ),
                  ),
                if (value.partOfSpeech != null)
                  Text(
                    value.partOfSpeech!.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ],
          if (example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"$example"',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMain,
                height: 1.4,
              ),
            ),
          ],
          if (exampleTranslation.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              exampleTranslation,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.border,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final upper = label.toUpperCase();
    final Color bg;
    final Color fg;
    final Color border;

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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
