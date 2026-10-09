import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../data/phrase_api.dart';
import '../state/phrase_form_controller.dart';
import '../state/phrase_list_controller.dart';
import 'widgets/phrase_detail_sheet.dart';

/// Màn hình nhập và gửi đoạn văn bản để AI chấm điểm (act-11, seq-11, seq-12).
class PhraseFormScreen extends StatelessWidget {
  const PhraseFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PhraseFormController(ctx.read<PhraseApi>()),
      child: const _PhraseFormView(),
    );
  }
}

class _PhraseFormView extends StatelessWidget {
  const _PhraseFormView();

  static const List<String> _samplePhrases = [
    'I has went to school yesterday with my best friends.',
    'Although it was raining heavily, but we still decided to go out.',
    'English has become an essential language in the modern globalization era.',
    'He do not likes eating spicy food at all.',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhraseFormController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm đoạn văn bằng AI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner AI Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.aiBg, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.aiPurple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.aiPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppTheme.aiPurple, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trợ lý chấm điểm & Chữa bài AI',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.aiPurple,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Nhập đoạn văn (10–5000 ký tự) để được chấm điểm thang 10, chỉ ra lỗi sai và câu sửa chuẩn.',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Error notice
            if (controller.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Input TextField
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: controller.textController,
                      maxLines: 8,
                      minLines: 5,
                      onChanged: (_) => (context as Element).markNeedsBuild(),
                      decoration: const InputDecoration(
                        hintText: 'Nhập câu hoặc đoạn văn tiếng Anh của bạn tại đây...\nVí dụ: I has went to school yesterday.',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Text(
                          '${controller.characterCount} ký tự',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: controller.characterCount < 10
                                ? AppTheme.errorRed
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _showQuickTemplates(context, controller),
                          icon: const Icon(Icons.lightbulb_outline, size: 18),
                          label: const Text('Mẫu thử'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: controller.isGrading ? null : () => _submit(context, controller),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.aiPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: controller.isGrading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('AI đang chấm điểm & phân tích...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Chấm điểm & Sửa lỗi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickTemplates(BuildContext context, PhraseFormController controller) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn câu mẫu để thử nghiệm:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ..._samplePhrases.map((phrase) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.article_outlined, color: AppTheme.primaryBlue),
                  title: Text(phrase, style: const TextStyle(fontSize: 13.5)),
                  onTap: () {
                    controller.setText(phrase);
                    Navigator.of(ctx).pop();
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, PhraseFormController controller) async {
    final result = await controller.submitForGrading();
    if (result != null && context.mounted) {
      // Cập nhật vào danh sách nếu có
      try {
        context.read<PhraseListController>().addOrUpdatePhrase(result);
      } catch (_) {}

      // Mở modal kết quả chi tiết
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PhraseDetailSheet(phrase: result),
      );
    }
  }
}
