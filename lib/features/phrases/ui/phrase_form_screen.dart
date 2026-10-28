import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/ocr/ocr_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/phrase_api.dart';
import '../state/phrase_form_controller.dart';
import '../state/phrase_list_controller.dart';
import 'widgets/phrase_detail_sheet.dart';

/// Màn hình nhập và gửi đoạn văn bản để AI chấm điểm (act-11, seq-11, seq-12),
/// tích hợp Quét OCR lấy văn bản từ ảnh on-device (act-17, seq-17).
class PhraseFormScreen extends StatelessWidget {
  const PhraseFormScreen({super.key, this.initialText, this.autoScan = false});

  final String? initialText;
  final bool autoScan;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) {
        final controller = PhraseFormController(ctx.read<PhraseApi>());
        if (initialText != null && initialText!.isNotEmpty) {
          controller.setText(initialText!);
        }
        return controller;
      },
      child: _PhraseFormView(autoScan: autoScan),
    );
  }
}

class _PhraseFormView extends StatefulWidget {
  const _PhraseFormView({this.autoScan = false});

  final bool autoScan;

  @override
  State<_PhraseFormView> createState() => _PhraseFormViewState();
}

class _PhraseFormViewState extends State<_PhraseFormView> {
  final OcrService _ocrService = OcrService();
  bool _isProcessingOcr = false;

  static const List<String> _samplePhrases = [
    'I has went to school yesterday with my best friends.',
    'Although it was raining heavily, but we still decided to go out.',
    'English has become an essential language in the modern globalization era.',
    'He do not likes eating spicy food at all.',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final controller = context.read<PhraseFormController>();
          _scanOcr(controller);
        }
      });
    }
  }

  Future<void> _scanOcr(PhraseFormController controller) async {
    final source = await showModalBottomSheet<ImageSource>(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.aiPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: AppTheme.aiPurple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Quét OCR trích xuất chữ (act-17)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Chọn nguồn ảnh chứa văn bản tiếng Anh để nhận diện bằng ML Kit on-device và điền vào ô Chấm bài:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.aiBg,
                child: Icon(Icons.camera_alt_rounded, color: AppTheme.aiPurple),
              ),
              title: const Text(
                'Chụp ảnh mới bằng Camera',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Chụp đề bài, sách hoặc tài liệu tiếng Anh',
                style: TextStyle(fontSize: 12.5),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.aiBg,
                child: Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.aiPurple,
                ),
              ),
              title: const Text(
                'Chọn ảnh từ Thư viện (Gallery)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Chọn ảnh chụp màn hình hoặc tài liệu có sẵn',
                style: TextStyle(fontSize: 12.5),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    setState(() => _isProcessingOcr = true);

    try {
      final image = await _ocrService.pickImage(source);
      if (image == null) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Đang tiền xử lý ảnh & chạy ML Kit OCR...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final extractedText = await _ocrService.extractText(image);

      if (!mounted) return;

      if (extractedText == null || extractedText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy văn bản trong ảnh'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      } else {
        controller.setText(extractedText.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã trích xuất ${extractedText.trim().length} ký tự từ ảnh thành công.',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi quét ảnh OCR: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhraseFormController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm đoạn văn bằng AI'),
        actions: [
          IconButton(
            tooltip: 'Quét ảnh (OCR)',
            icon: _isProcessingOcr
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_rounded),
            onPressed: (_isProcessingOcr || controller.isGrading)
                ? null
                : () => _scanOcr(controller),
          ),
        ],
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
                border: Border.all(
                  color: AppTheme.aiPurple.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.aiPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.aiPurple,
                      size: 24,
                    ),
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
                          'Nhập đoạn văn hoặc quét từ ảnh để chấm điểm thang 10, chỉ ra lỗi sai và câu sửa chuẩn.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textMuted,
                          ),
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
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorRed,
                      size: 20,
                    ),
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
                      decoration: const InputDecoration(
                        hintText: 'Nhập câu hoặc đoạn văn tiếng Anh của bạn tại đây, hoặc bấm Quét ảnh (OCR)...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        // Đếm ký tự theo nội dung ô nhập, không cần ép cả màn
                        // hình build lại bằng markNeedsBuild.
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller.textController,
                          builder: (context, value, _) {
                            final count = value.text.trim().length;
                            return Text(
                              '$count ký tự',
                              style: TextStyle(
                                fontSize: 12,
                                color: count < 10
                                    ? AppTheme.errorRed
                                    : AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      (_isProcessingOcr || controller.isGrading)
                                      ? null
                                      : () => _scanOcr(controller),
                                  icon: _isProcessingOcr
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.aiPurple,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.document_scanner_rounded,
                                          size: 15,
                                        ),
                                  label: Text(
                                    _isProcessingOcr
                                        ? 'Đang quét…'
                                        : 'Quét ảnh (OCR)',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.aiPurple,
                                    side: const BorderSide(
                                      color: AppTheme.aiPurple,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showQuickTemplates(context, controller),
                                  icon: const Icon(
                                    Icons.lightbulb_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Mẫu câu'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
              onPressed: controller.isGrading
                  ? null
                  : () => _submit(context, controller),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickTemplates(
    BuildContext context,
    PhraseFormController controller,
  ) {
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
            ..._samplePhrases.map(
              (phrase) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.article_outlined,
                  color: AppTheme.primaryBlue,
                ),
                title: Text(phrase, style: const TextStyle(fontSize: 13.5)),
                onTap: () {
                  controller.setText(phrase);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    PhraseFormController controller,
  ) async {
    final result = await controller.submitForGrading();
    if (result != null && context.mounted) {
      try {
        context.read<PhraseListController>().addOrUpdatePhrase(result);
      } catch (_) {}

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PhraseDetailSheet(phrase: result),
      );
    }
  }
}
