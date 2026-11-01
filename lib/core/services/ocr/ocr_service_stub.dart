import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_service.dart';

/// Fallback cho nền tảng không có `dart:io` lẫn `dart:js_interop`
/// (thực tế hiếm gặp; web dùng `WebOcrService`, mobile/desktop dùng `MobileOcrService`).
class StubOcrService implements OcrService {
  final ImagePicker _picker = ImagePicker();

  @override
  bool get isSupported => false;

  @override
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
    } catch (e) {
      debugPrint('StubOcrService: chọn ảnh thất bại ($e).');
      return null;
    }
  }

  @override
  Future<OcrResult> extractText(
    XFile image, {
    OcrProgressCallback? onProgress,
  }) async {
    return const OcrResult.unsupported(
      message: 'Nền tảng hiện tại chưa có engine OCR. '
          'Vui lòng dùng ứng dụng Android/iOS hoặc bản web.',
    );
  }
}

OcrService createOcrService() => StubOcrService();
