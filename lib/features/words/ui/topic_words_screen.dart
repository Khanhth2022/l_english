import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/word_draft.dart';
import '../data/word_api.dart';
import '../state/word_list_controller.dart';

/// Màn hình AI Thêm từ mới theo chủ đề (act-20, seq-20).
class TopicWordsScreen extends StatefulWidget {
  const TopicWordsScreen({super.key});

  @override
  State<TopicWordsScreen> createState() => _TopicWordsScreenState();
}

class _TopicWordsScreenState extends State<TopicWordsScreen> {
  final _topicController = TextEditingController();
  final Set<int> _selectedIndices = {};

  bool _isGenerating = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<WordDraft> _suggestedWords = [];

  static const List<String> _quickTopics = [
    'Công sở',
    'Du lịch',
    'Công nghệ',
    'Ẩm thực',
    'Môi trường',
    'Giáo dục',
  ];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateWords() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập chủ đề từ vựng cần sinh.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _suggestedWords = [];
      _selectedIndices.clear();
    });

    try {
      final api = context.read<WordApi>();
      final result = await api.generateTopicWords(topic);
      if (result.isEmpty) {
        setState(() => _errorMessage = 'AI không tìm thấy từ mới nào cho chủ đề này hoặc các từ đều đã có trong sổ.');
      } else {
        setState(() {
          _suggestedWords = result;
          // Mặc định chọn tất cả
          _selectedIndices.addAll(List.generate(result.length, (i) => i));
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi sinh từ: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveSelectedWords() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa chọn từ nào để thêm vào sổ.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final selectedList = _selectedIndices.map((i) => _suggestedWords[i]).toList();
      final api = context.read<WordApi>();
      final saved = await api.confirmTopicWords(selectedList);

      if (!mounted) return;
      await context.read<WordListController>().load();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${saved.length} từ mới vào sổ từ của bạn!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi lưu từ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm từ theo chủ đề (AI)'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.aiBg, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.aiPurple.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.aiPurple.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology_alt_rounded, color: AppTheme.aiPurple, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Đề xuất 10 từ theo chủ đề',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.aiPurple,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tự động lọc bỏ các từ đã có trong sổ từ của bạn để đảm bảo không bị trùng lặp.',
                              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Error message
                if (_errorMessage != null) ...[
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
                            _errorMessage!,
                            style: const TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Topic Input Box
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _topicController,
                          decoration: InputDecoration(
                            labelText: 'Nhập chủ đề',
                            hintText: 'Ví dụ: Công sở, Du lịch, Môi trường...',
                            prefixIcon: const Icon(Icons.topic_outlined),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _isGenerating ? null : _generateWords,
                            ),
                          ),
                          onSubmitted: (_) => _generateWords(),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gợi ý nhanh chủ đề:',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _quickTopics.map((topic) {
                            return ActionChip(
                              label: Text(topic),
                              onPressed: () {
                                _topicController.text = topic;
                                _generateWords();
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Generating Loader or Word List
                if (_isGenerating) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: const [
                          CircularProgressIndicator(color: AppTheme.aiPurple),
                          SizedBox(height: 16),
                          Text(
                            'AI đang phân tích và sinh 10 từ phù hợp...',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.aiPurple),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_suggestedWords.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'Danh sách từ đề xuất (${_suggestedWords.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedIndices.length == _suggestedWords.length) {
                              _selectedIndices.clear();
                            } else {
                              _selectedIndices.addAll(List.generate(_suggestedWords.length, (i) => i));
                            }
                          });
                        },
                        child: Text(
                          _selectedIndices.length == _suggestedWords.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_suggestedWords.length, (index) {
                    final draft = _suggestedWords[index];
                    final isSelected = _selectedIndices.contains(index);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIndices.add(index);
                            } else {
                              _selectedIndices.remove(index);
                            }
                          });
                        },
                        title: Row(
                          children: [
                            Text(
                              draft.english,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            if (draft.level != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  draft.level!.wire,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            ...draft.values.map((v) => Text(
                                  '• ${v.vietnamese} ${v.pronunciation != null ? "(${v.pronunciation})" : ""}',
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
                                )),
                            if (draft.values.isNotEmpty && draft.values.first.example != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '"${draft.values.first.example!}"',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // Bottom Action Bar
          if (_suggestedWords.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Text(
                      'Đã chọn: ${_selectedIndices.length}/${_suggestedWords.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSelectedWords,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bookmark_add_rounded),
                      label: Text(_isSaving ? 'Đang lưu...' : 'Lưu vào sổ từ'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
