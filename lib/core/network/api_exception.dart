/// Lỗi của tầng gọi API, quy về đúng các mã HTTP mà tài liệu thiết kế dùng:
///
/// | Mã  | Ý nghĩa trong chức năng Quản lý từ                          |
/// |-----|-------------------------------------------------------------|
/// | 400 | Dữ liệu gửi lên sai, hoặc `english` không phải tiếng Anh     |
/// | 401 | Access token thiếu / hỏng / hết hạn                          |
/// | 403 | Không sở hữu dữ liệu (sửa-xóa từ của người khác)             |
/// | 409 | Trùng từ: vi phạm UNIQUE (user_id, english)                  |
/// | 502 | Dịch vụ AI lỗi hoặc quá thời gian chờ                        |
///
/// statusCode = 0 dùng cho lỗi không có phản hồi (mất mạng, timeout).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.isNetworkError = false});

  /// Dựng lỗi từ phản hồi HTTP. Nếu backend có gửi kèm thông báo
  /// (`{"message": "..."}`) thì ưu tiên hiển thị thông báo đó.
  factory ApiException.fromStatus(int statusCode, [Object? body]) {
    final fromServer = _messageFromBody(body);
    return ApiException(statusCode, fromServer ?? _defaultMessage(statusCode));
  }

  factory ApiException.network([String? detail]) => ApiException(
    0,
    detail ?? 'Không kết nối được tới máy chủ. Kiểm tra lại địa chỉ API và wifi.',
    isNetworkError: true,
  );

  final int statusCode;
  final String message;
  final bool isNetworkError;

  bool get isBadRequest => statusCode == 400;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;
  bool get isAiFailure => statusCode == 502;

  static String _defaultMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Dữ liệu không hợp lệ. Kiểm tra lại từ tiếng Anh và các nghĩa đã nhập.';
      case 401:
        return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
      case 403:
        return 'Bạn không có quyền với dữ liệu này.';
      case 404:
        return 'Không tìm thấy dữ liệu.';
      case 409:
        return 'Từ này đã có trong sổ từ của bạn.';
      case 502:
        return 'Dịch vụ AI đang lỗi, vui lòng thử lại sau.';
      default:
        if (statusCode >= 500) {
          return 'Máy chủ gặp lỗi ($statusCode), vui lòng thử lại sau.';
        }
        return 'Yêu cầu thất bại ($statusCode).';
    }
  }

  static String? _messageFromBody(Object? body) {
    if (body is Map) {
      for (final key in const ['message', 'error', 'detail', 'title']) {
        final value = body[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    if (body is String) {
      final text = body.trim();
      if (text.isNotEmpty && text.length <= 300) {
        return text;
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Token hết hạn và không làm mới được → người dùng phải đăng nhập lại.
class SessionExpiredException extends ApiException {
  SessionExpiredException()
    : super(401, 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
}
