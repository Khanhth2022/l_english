import 'package:image_picker/image_picker.dart';

import 'ocr_service_stub.dart'
    if (dart.library.io) 'ocr_service_mobile.dart';

/// Dịch vụ Quét OCR văn bản on-device bằng ML Kit (act-17, seq-17).
abstract class OcrService {
  factory OcrService() => createOcrService();

  /// Mở camera hoặc thư viện để chọn ảnh.
  Future<XFile?> pickImage(ImageSource source);

  /// Tiền xử lý và chạy nhận diện chữ OCR Latin (tiếng Anh) từ ảnh.
  /// Trả về chuỗi văn bản nhận dạng được, hoặc `null` nếu không tìm thấy văn bản.
  Future<String?> extractText(XFile image);
}
