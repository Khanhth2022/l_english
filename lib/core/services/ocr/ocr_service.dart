import 'package:image_picker/image_picker.dart';

import 'ocr_service_stub.dart'
    if (dart.library.js_interop) 'ocr_service_web.dart'
    if (dart.library.io) 'ocr_service_mobile.dart';

/// Trạng thái của một lần quét OCR.
///
/// Tách riêng khỏi chuỗi kết quả để màn hình phân biệt được "ảnh không có chữ"
/// với "nền tảng không hỗ trợ OCR" hay "engine OCR lỗi" — trước đây cả ba
/// trường hợp đều hiển thị chung một câu "Không tìm thấy văn bản trong ảnh".
enum OcrStatus {
  /// Nhận diện thành công và có văn bản.
  success,

  /// Engine chạy được nhưng không tìm thấy chữ nào trong ảnh.
  empty,

  /// Nền tảng hiện tại không có engine OCR (ví dụ Windows/Linux desktop).
  unsupported,

  /// Engine lỗi (mất mạng, không tải được model, ảnh hỏng...).
  failed,
}

/// Báo tiến trình cho UI trong lúc quét.
///
/// [progress] nằm trong khoảng 0..1, hoặc `null` khi engine không báo được
/// phần trăm (ML Kit trên mobile không có tiến trình).
typedef OcrProgressCallback = void Function(double? progress, String? stage);

/// Kết quả của một lần quét OCR.
class OcrResult {
  const OcrResult.success(String this.text)
    : status = OcrStatus.success,
      message = null;

  const OcrResult.empty({this.message})
    : status = OcrStatus.empty,
      text = null;

  const OcrResult.unsupported({this.message})
    : status = OcrStatus.unsupported,
      text = null;

  const OcrResult.failed({this.message})
    : status = OcrStatus.failed,
      text = null;

  final OcrStatus status;

  /// Văn bản nhận diện được, chỉ khác `null` khi [status] là [OcrStatus.success].
  final String? text;

  /// Thông điệp kỹ thuật/giải thích cho người dùng, có thể `null`.
  final String? message;

  /// `true` khi có văn bản thật sự để điền vào ô nhập.
  bool get hasText => status == OcrStatus.success && (text?.trim().isNotEmpty ?? false);

  @override
  String toString() => 'OcrResult(${status.name}, ${text?.length ?? 0} ký tự'
      '${message == null ? '' : ', message: $message'})';
}

/// Dịch vụ Quét OCR văn bản on-device (act-17, seq-17).
///
/// - Android/iOS: Google ML Kit Text Recognition (Latin).
/// - Web: Tesseract.js chạy trong trình duyệt (xem `web/ocr_bridge.js`).
/// - Desktop (Windows/Linux/macOS): chưa có engine, trả về
///   [OcrStatus.unsupported] thay vì báo sai là "không tìm thấy văn bản".
abstract class OcrService {
  factory OcrService() => createOcrService();

  /// Nền tảng hiện tại có engine OCR hay không.
  bool get isSupported;

  /// Mở camera hoặc thư viện để chọn ảnh.
  Future<XFile?> pickImage(ImageSource source);

  /// Tiền xử lý và chạy nhận diện chữ OCR Latin (tiếng Anh) từ ảnh.
  Future<OcrResult> extractText(
    XFile image, {
    OcrProgressCallback? onProgress,
  });
}
