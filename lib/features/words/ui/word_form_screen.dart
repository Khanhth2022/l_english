import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/enums.dart';
import '../data/models/word.dart';
import '../data/word_api.dart';
import '../state/word_form_controller.dart';
import 'widgets/word_value_editor.dart';

/// Màn hình Thêm từ / Sửa từ.
///
/// Khi lưu thành công, màn hình trả về `true` để danh sách tải lại.
class WordFormScreen extends StatelessWidget {
  const WordFormScreen({super.key, this.existing});

  /// `null` nghĩa là thêm từ mới.
  final Word? existing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          WordFormController(api: ctx.read<WordApi>(), existing: existing),
      child: const _WordFormView(),
    );
  }
}

class _WordFormView extends StatelessWidget {
  const _WordFormView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WordFormController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.title),
        actions: [
          TextButton.icon(
            onPressed: controller.saving ? null : () => _save(context),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: controller.saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: controller.englishController,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Từ tiếng Anh *',
                hintText: 'ví dụ: resilient',
                border: OutlineInputBorder(),
                helperText:
                    'Phải là tiếng Anh và không trùng từ đã có trong sổ '
                    '(trùng sẽ báo lỗi 409).',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Level>(
              initialValue: controller.level,
              decoration: const InputDecoration(
                labelText: 'Trình độ (CEFR)',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Chưa chọn'),
              items: [
                for (final level in Level.values)
                  DropdownMenuItem(value: level, child: Text(level.wire)),
              ],
              onChanged: controller.setLevel,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: controller.generating
                    ? null
                    : () => _generate(context),
                icon: controller.generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  controller.generating ? 'Đang nhờ AI…' : 'Gợi ý nghĩa bằng AI',
                ),
              ),
            ),
            if (controller.notice != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.notice!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nghĩa của từ',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm nghĩa'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (index, row) in controller.rows.indexed)
              Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(bottom: 12),
                child: WordValueEditor(
                  row: row,
                  index: index,
                  canRemove: controller.rows.length > 1,
                  onRemove: () => controller.removeRow(row),
                  onPartOfSpeechChanged: (value) =>
                      controller.setPartOfSpeech(row, value),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: controller.saving ? null : () => _save(context),
              icon: const Icon(Icons.save_outlined),
              label: Text(controller.isEditing ? 'Cập nhật từ' : 'Thêm vào sổ từ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final controller = context.read<WordFormController>();
    final error = await controller.save();
    if (!context.mounted) return;
    if (error != null) {
      _showMessage(context, error, isError: true);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _generate(BuildContext context) async {
    final controller = context.read<WordFormController>();
    final error = await controller.generateMeaning();
    if (!context.mounted || error == null) return;
    _showMessage(context, error, isError: true);
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}
