import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_service.dart';

class StubOcrService implements OcrService {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
    } catch (e) {
      debugPrint('Lỗi chọn ảnh: $e');
      return null;
    }
  }

  @override
  Future<String?> extractText(XFile image) async {
    // Trên môi trường Web/Stub: không có ML Kit native
    return null;
  }
}

OcrService createOcrService() => StubOcrService();
