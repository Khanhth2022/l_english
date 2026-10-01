/// Định dạng ngày theo kiểu Việt Nam, viết tay để không phải thêm package `intl`.
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatDateOrDash(DateTime? date) => date == null ? '—' : formatDate(date);

/// Mô tả lịch ôn kế tiếp so với hiện tại.
String formatDueLabel(DateTime? nextReview, DateTime now) {
  if (nextReview == null) return 'chưa ôn lần nào';
  final days = _dayDifference(nextReview, now);
  if (days < 0) return 'quá hạn ${-days} ngày';
  if (days == 0) return 'đến hạn hôm nay';
  if (days == 1) return 'ôn lại ngày mai';
  return 'ôn lại ${formatDate(nextReview)}';
}

int _dayDifference(DateTime target, DateTime now) {
  final a = DateTime(target.year, target.month, target.day);
  final b = DateTime(now.year, now.month, now.day);
  return a.difference(b).inDays;
}
