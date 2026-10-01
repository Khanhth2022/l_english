/// Đọc dữ liệu JSON "chịu lỗi": backend có thể trả về null, số dạng chuỗi hoặc
/// thiếu khoá, nên mọi chỗ chuyển kiểu đều đi qua đây thay vì ép kiểu trực tiếp.
library;

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String? asStringOrNull(Object? value) {
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  if (value is num || value is bool) return value.toString();
  return null;
}

String asString(Object? value, {String fallback = ''}) =>
    asStringOrNull(value) ?? fallback;

/// Đọc mốc thời gian ISO-8601. Backend dùng `LocalDateTime` nên chuỗi thường
/// không kèm múi giờ; nếu có kèm (`Z`, `+07:00`) thì đổi về giờ máy.
DateTime? asDateTime(Object? value) {
  final text = asStringOrNull(value);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

/// Đọc danh sách đối tượng con, bỏ qua phần tử sai định dạng.
List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
