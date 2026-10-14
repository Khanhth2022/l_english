import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../state/word_form_controller.dart';

/// Khối nhập một nghĩa của từ trong form Thêm/Sửa.
class WordValueEditor extends StatelessWidget {
  const WordValueEditor({
    super.key,
    required this.row,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onPartOfSpeechChanged,
  });

  final WordValueRow row;

  /// Thứ tự dòng, chỉ dùng để hiện tiêu đề "Nghĩa 1", "Nghĩa 2"…
  final int index;

  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<PartOfSpeech?> onPartOfSpeechChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Nghĩa ${index + 1}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: canRemove
                      ? 'Xoá nghĩa này'
                      : 'Từ cần ít nhất một nghĩa',
                  onPressed: canRemove ? onRemove : null,
                  icon: Icon(
                    Icons.delete_outline,
                    color: canRemove ? AppTheme.errorRed : AppTheme.textMuted.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: row.vietnameseController,
              decoration: const InputDecoration(
                labelText: 'Nghĩa tiếng Việt *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PartOfSpeech>(
              initialValue: row.partOfSpeech,
              decoration: const InputDecoration(
                labelText: 'Từ loại',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Chưa chọn'),
              items: [
                for (final item in PartOfSpeech.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: onPartOfSpeechChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.pronunciationController,
              decoration: const InputDecoration(
                labelText: 'Phiên âm',
                hintText: '/rɪˈzɪliənt/',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.exampleController,
              decoration: const InputDecoration(
                labelText: 'Ví dụ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.exampleTranslationController,
              decoration: const InputDecoration(
                labelText: 'Dịch ví dụ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              minLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
