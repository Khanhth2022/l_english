import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/word.dart';
import '../state/word_list_controller.dart';

/// Màn hình câu hỏi ôn tập tương tác (Review Quiz) theo thuật toán Spaced Repetition (SRS).
///
/// Hỗ trợ:
/// - Mở từ Widget màn hình chính (ACT-15).
/// - Trắc nghiệm 4 đáp án chọn nghĩa đúng kèm phản hồi tức thì.
/// - Gợi ý câu ví dụ và phiên âm quốc tế IPA.
/// - Tự động ghi nhận ôn tập (ACT-19) qua API `/api/words/review` và đồng bộ Widget.
class ReviewQuizScreen extends StatefulWidget {
  const ReviewQuizScreen({
    super.key,
    required this.words,
    this.allWords = const [],
  });

  /// Danh sách từ cần ôn hôm nay.
  final List<Word> words;

  /// Toàn bộ từ trong sổ từ (dùng tạo các đáp án gây nhiễu).
  final List<Word> allWords;

  @override
  State<ReviewQuizScreen> createState() => _ReviewQuizScreenState();
}

class _ReviewQuizScreenState extends State<ReviewQuizScreen> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  int _correctCount = 0;
  final Set<int> _reviewedWordIds = {};

  late List<_QuizQuestion> _questions;
  bool _isFinished = false;
  bool _submitting = false;
  bool _showClue = false;

  @override
  void initState() {
    super.initState();
    _buildQuestions();
  }

  void _buildQuestions() {
    final rng = Random();
    final allMeanings = <String>{};
    for (final w in widget.allWords) {
      for (final v in w.values) {
        if (v.vietnamese.trim().isNotEmpty) {
          allMeanings.add(v.vietnamese.trim());
        }
      }
    }

    const fallbackDistractors = [
      'kiên trì, bền bỉ',
      'duy trì, gìn giữ',
      'phát triển vượt bậc',
      'thích nghi linh hoạt',
      'tác động sâu sắc',
      'vượt qua thử thách',
      'cải thiện đáng kể',
      'cam kết lâu dài',
    ];

    _questions = widget.words.map((word) {
      final correctMeaning = word.values.isNotEmpty
          ? word.values.first.vietnamese.trim()
          : 'Không có nghĩa';

      // Chọn 3 đáp án sai khác
      final distractors = allMeanings
          .where((m) => m != correctMeaning)
          .toList()
        ..shuffle(rng);

      final chosen = <String>[];
      for (final m in distractors) {
        if (chosen.length >= 3) break;
        if (!chosen.contains(m)) chosen.add(m);
      }

      var fallbackIdx = 0;
      while (chosen.length < 3 && fallbackIdx < fallbackDistractors.length) {
        final fb = fallbackDistractors[fallbackIdx++];
        if (fb != correctMeaning && !chosen.contains(fb)) {
          chosen.add(fb);
        }
      }

      final options = [correctMeaning, ...chosen]..shuffle(rng);
      final correctIdx = options.indexOf(correctMeaning);

      return _QuizQuestion(
        word: word,
        correctMeaning: correctMeaning,
        options: options,
        correctOptionIndex: correctIdx,
      );
    }).toList();
  }

  void _onSelectOption(int index) {
    if (_isAnswered) return;

    final q = _questions[_currentIndex];
    final isCorrect = index == q.correctOptionIndex;

    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;
      if (isCorrect) {
        _correctCount++;
      }
      _reviewedWordIds.add(q.word.id);
    });
  }

  void _onGiveUp() {
    if (_isAnswered) return;
    final q = _questions[_currentIndex];
    setState(() {
      _selectedOptionIndex = -1; // -1: người dùng không chọn mà xem đáp án
      _isAnswered = true;
      _reviewedWordIds.add(q.word.id);
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswered = false;
        _showClue = false;
      });
    } else {
      setState(() {
        _isFinished = true;
      });
    }
  }

  Future<void> _completeReview() async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = context.read<WordListController>();
    final error = await controller.confirmReviewWords(_reviewedWordIds.toList());

    if (!mounted) return;
    setState(() {
      _submitting = false;
    });

    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Đã cập nhật tiến độ ôn tập cho ${_reviewedWordIds.length} từ!',
        ),
        backgroundColor: AppTheme.successGreen,
      ),
    );
    navigator.pop(true);
  }

  Future<bool> _onWillPop() async {
    if (_isFinished || _questions.isEmpty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dừng ôn tập?'),
        content: const Text(
          'Bạn đang trong phiên ôn tập. Nếu thoát bây giờ, các từ vừa trả lời sẽ chưa được lưu vào hệ thống SRS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tiếp tục ôn'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isFinished || _questions.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Đóng',
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _isFinished
                ? 'Kết quả ôn tập'
                : 'Câu hỏi ${_currentIndex + 1}/${_questions.length}',
          ),
          actions: [
            if (!_isFinished && _questions.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.successGreen),
                        const SizedBox(width: 4),
                        Text(
                          '$_correctCount đúng',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          bottom: !_isFinished && _questions.isNotEmpty
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    backgroundColor: AppTheme.borderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                )
              : null,
        ),
        body: _questions.isEmpty
            ? _buildEmptyState()
            : _isFinished
                ? _buildFinishedState()
                : _buildQuestionView(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_rounded, size: 64, color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            const Text(
              'Không có từ nào cần ôn tập hôm nay!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn đã hoàn thành tốt các bài ôn tập. Hãy thêm từ mới hoặc quay lại sau nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Quay lại sổ từ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView() {
    final q = _questions[_currentIndex];
    final word = q.word;
    final primaryVal = word.values.isNotEmpty ? word.values.first : null;
    final phonetic = primaryVal?.pronunciation;
    final example = primaryVal?.example;
    final exampleTr = primaryVal?.exampleTranslation;
    final pos = primaryVal?.partOfSpeech;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Thẻ hiển thị từ vựng
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (word.level != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              word.level!.wire,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        if (pos != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.aiBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pos.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.aiPurple,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      word.english,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textMain,
                      ),
                    ),
                    if (phonetic != null && phonetic.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        phonetic,
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                    if (example != null && example.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      if (!_showClue)
                        TextButton.icon(
                          onPressed: () => setState(() => _showClue = true),
                          icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                          label: const Text('Xem câu ví dụ gợi ý'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.warningOrange,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                example,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              if (exampleTr != null && exampleTr.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  exampleTr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Chọn nghĩa tiếng Việt chính xác:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 4 Lựa chọn câu hỏi
              for (int i = 0; i < q.options.length; i++)
                _buildOptionCard(
                  index: i,
                  optionText: q.options[i],
                  correctIndex: q.correctOptionIndex,
                ),
            ],
          ),
        ),

        // Thanh điều hướng phía dưới
        _buildBottomBar(q),
      ],
    );
  }

  Widget _buildOptionCard({
    required int index,
    required String optionText,
    required int correctIndex,
  }) {
    final letters = ['A', 'B', 'C', 'D'];
    final letter = index < letters.length ? letters[index] : '${index + 1}';

    Color cardBg = Colors.white;
    Color borderColor = AppTheme.borderLight;
    Color textColor = AppTheme.textMain;
    IconData? trailingIcon;
    Color? trailingColor;

    if (_isAnswered) {
      if (index == correctIndex) {
        cardBg = AppTheme.successBg;
        borderColor = AppTheme.successGreen;
        textColor = AppTheme.successGreen;
        trailingIcon = Icons.check_circle_rounded;
        trailingColor = AppTheme.successGreen;
      } else if (index == _selectedOptionIndex) {
        cardBg = AppTheme.errorBg;
        borderColor = AppTheme.errorRed;
        textColor = AppTheme.errorRed;
        trailingIcon = Icons.cancel_rounded;
        trailingColor = AppTheme.errorRed;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _isAnswered ? null : () => _onSelectOption(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: (_isAnswered && (index == correctIndex || index == _selectedOptionIndex))
                    ? 2
                    : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (_isAnswered && index == correctIndex)
                        ? AppTheme.successGreen
                        : (_isAnswered && index == _selectedOptionIndex)
                            ? AppTheme.errorRed
                            : AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: (_isAnswered &&
                                (index == correctIndex || index == _selectedOptionIndex))
                            ? Colors.white
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    optionText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: trailingColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(_QuizQuestion q) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: _isAnswered
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedOptionIndex == q.correctOptionIndex
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 18,
                              color: _selectedOptionIndex == q.correctOptionIndex
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedOptionIndex == q.correctOptionIndex
                                    ? 'Chính xác!'
                                    : 'Chưa chính xác!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedOptionIndex == q.correctOptionIndex
                                      ? AppTheme.successGreen
                                      : AppTheme.errorRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedOptionIndex != q.correctOptionIndex) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Đáp án: ${q.correctMeaning}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _nextQuestion,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      _currentIndex < _questions.length - 1
                          ? 'Câu kế tiếp'
                          : 'Xem kết quả',
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _onGiveUp,
                    icon: const Icon(Icons.help_outline_rounded, size: 16),
                    label: const Text('Xem đáp án'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chạm một đáp án để kiểm tra',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFinishedState() {
    final total = _questions.length;
    final accuracy = total > 0 ? ((_correctCount / total) * 100).round() : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppTheme.aiBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 50,
                color: AppTheme.aiPurple,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hoàn thành phiên ôn tập!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã ôn lại xong $total từ vựng hôm nay.',
              style: const TextStyle(fontSize: 15, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 28),

            // Thống kê kết quả
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Số câu đúng', '$_correctCount/$total', AppTheme.primaryBlue),
                  ),
                  Container(width: 1, height: 40, color: AppTheme.borderLight),
                  Expanded(
                    child: _buildStatItem('Độ chính xác', '$accuracy%', AppTheme.successGreen),
                  ),
                  Container(width: 1, height: 40, color: AppTheme.borderLight),
                  Expanded(
                    child: _buildStatItem('Cập nhật SRS', '${_reviewedWordIds.length} từ', AppTheme.aiPurple),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textMuted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lịch ôn của các từ này sẽ tự động được dời xa hơn theo thuật toán Spaced Repetition (SRS).',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _completeReview,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _submitting
                      ? 'Đang cập nhật tiến độ SRS…'
                      : 'Xác nhận & Cập nhật tiến độ',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _QuizQuestion {
  _QuizQuestion({
    required this.word,
    required this.correctMeaning,
    required this.options,
    required this.correctOptionIndex,
  });

  final Word word;
  final String correctMeaning;
  final List<String> options;
  final int correctOptionIndex;
}
