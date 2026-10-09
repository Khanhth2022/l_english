import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../phrases/ui/phrase_form_screen.dart';
import '../../words/data/word_api.dart';
import '../../words/ui/word_form_screen.dart';

/// Màn hình tương tác và mô phỏng 4 tính năng tích hợp hệ điều hành Android (act-14..17).
class AndroidFeaturesScreen extends StatefulWidget {
  const AndroidFeaturesScreen({super.key});

  @override
  State<AndroidFeaturesScreen> createState() => _AndroidFeaturesScreenState();
}

class _AndroidFeaturesScreenState extends State<AndroidFeaturesScreen> {
  bool _notificationEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 20, minute: 0);

  static const List<Map<String, String>> _ocrSamples = [
    {
      'title': 'Đoạn trích từ bài tập IELTS',
      'text': 'Although online learning provides great flexibility, but students often face difficulties with self-discipline.',
    },
    {
      'title': 'Đoạn trích tin tức môi trường',
      'text': 'Renewable energy has become more cheaper than fossil fuels in many developing countries.',
    },
    {
      'title': 'Ghi chú tiếng Anh công sở',
      'text': 'We look forward to hear your feedback regarding the quarterly business proposal.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final wordApi = context.read<WordApi>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiện ích & Tích hợp Android'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.android_rounded, color: Colors.green, size: 32),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tính năng Hệ thống Android',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quét ảnh OCR, Widget màn hình chính, Thông báo ôn tập ngầm, Thêm từ qua bộ chọn văn bản.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tính năng 1: Scan OCR (act-17, seq-17)
          _buildFeatureCard(
            icon: Icons.document_scanner_rounded,
            iconColor: AppTheme.aiPurple,
            title: 'Quét OCR lấy văn bản (act-17)',
            description: 'Sử dụng ML Kit OCR on-device để trích xuất văn bản tiếng Anh từ ảnh/tài liệu và đưa thẳng vào ô Chấm đoạn văn.',
            action: ElevatedButton.icon(
              onPressed: () => _showOcrScanner(context),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Thử nghiệm Quét OCR'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.aiPurple),
            ),
          ),
          const SizedBox(height: 16),

          // Tính năng 2: Widget Màn hình chính (act-15, seq-15)
          FutureBuilder<int>(
            future: wordApi.fetchDueCount(),
            builder: (context, snapshot) {
              final dueCount = snapshot.data ?? 0;
              return _buildFeatureCard(
                icon: Icons.widgets_rounded,
                iconColor: AppTheme.primaryBlue,
                title: 'Widget màn hình chính (act-15)',
                description: 'AppWidgetProvider định kỳ gọi GET /api/words/due-count để cập nhật số từ đến hạn ôn ngay ngoài HomeScreen.',
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_stories, color: AppTheme.primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LEnglish • Ôn tập',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          Text(
                            '$dueCount từ cần ôn lại hôm nay',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Tính năng 3: Thông báo ôn tập định kỳ (act-14, seq-14)
          _buildFeatureCard(
            icon: Icons.notifications_active_rounded,
            iconColor: AppTheme.warningOrange,
            title: 'Thông báo ôn tập (act-14)',
            description: 'WorkManager và NotificationManager nhắc nhở ôn tập Spaced Repetition vào khung giờ cố định trong ngày.',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationEnabled,
                  title: const Text('Bật thông báo hằng ngày', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onChanged: (val) => setState(() => _notificationEnabled = val),
                ),
                if (_notificationEnabled)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Giờ nhận thông báo', style: TextStyle(fontSize: 13.5)),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _notificationTime,
                        );
                        if (picked != null) {
                          setState(() => _notificationTime = picked);
                        }
                      },
                      child: Text(
                        '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tính năng 4: Thêm từ từ bôi đen text (act-16, seq-16)
          _buildFeatureCard(
            icon: Icons.text_fields_rounded,
            iconColor: AppTheme.successGreen,
            title: 'Thêm từ từ bộ chọn văn bản (act-16)',
            description: 'Bôi đen bất kỳ từ tiếng Anh nào trên trình duyệt hay ứng dụng khác, chọn menu "LEnglish" để mở màn hình Thêm từ và tự động gọi AI sinh nghĩa.',
            action: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WordFormScreen()),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Thử mở màn Thêm từ'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    Widget? action,
    Widget? child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            if (child != null) ...[
              const SizedBox(height: 10),
              child,
            ],
            if (action != null) ...[
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerRight, child: action),
            ],
          ],
        ),
      ),
    );
  }

  void _showOcrScanner(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
              'Trích xuất văn bản (Mô phỏng OCR ML Kit)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn mẫu văn bản tiếng Anh để giả lập quét ảnh thành chữ và chuyển sang chấm bài:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ..._ocrSamples.map((sample) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.document_scanner, color: AppTheme.aiPurple),
                  title: Text(sample['title']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(sample['text']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PhraseFormScreen(),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
