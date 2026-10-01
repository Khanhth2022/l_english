import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Nghĩa ${index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: canRemove
                      ? 'Xoá nghĩa này'
                      : 'Từ cần ít nhất một nghĩa',
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
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
