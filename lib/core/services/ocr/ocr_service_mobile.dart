import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_service.dart';

/// Triển khai OCR thật sự bằng Google ML Kit Text Recognition on-device (act-17, seq-17).
class MobileOcrService implements OcrService {
  final ImagePicker _picker = ImagePicker();

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        // Giữ chất lượng cao để ML Kit không đọc nhầm chữ nhỏ sau khi nén JPEG.
        imageQuality: 95,
      );
    } catch (e) {
      debugPrint('Lỗi chọn ảnh: $e');
      return null;
    }
  }

  @override
  Future<OcrResult> extractText(
    XFile image, {
    OcrProgressCallback? onProgress,
  }) async {
    // Desktop (Windows/Linux/macOS) không có ML Kit: báo "không hỗ trợ"
    // thay vì trả null để UI hiển thị nhầm là "không tìm thấy văn bản".
    if (!isSupported) {
      return OcrResult.unsupported(
        message: 'Google ML Kit chỉ chạy trên Android/iOS. '
            'Trên ${Platform.operatingSystem} hãy dùng bản web hoặc thiết bị di động.',
      );
    }

    onProgress?.call(null, 'Đang nhận diện chữ (ML Kit on-device)…');

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text.trim();
      if (rawText.isEmpty) {
        return const OcrResult.empty(
          message: 'ML Kit không đọc được ký tự nào. '
              'Hãy chụp gần hơn, giữ trang giấy phẳng và đủ sáng.',
        );
      }
      return OcrResult.success(rawText);
    } on PlatformException catch (e) {
      debugPrint('Lỗi ML Kit OCR: ${e.code} - ${e.message}');
      return OcrResult.failed(
        message: 'ML Kit lỗi (${e.code}): ${e.message ?? 'không rõ nguyên nhân'}.',
      );
    } catch (e) {
      debugPrint('Lỗi ML Kit OCR: $e');
      return OcrResult.failed(message: 'Không chạy được ML Kit OCR ($e).');
    } finally {
      await textRecognizer.close();
    }
  }
}

OcrService createOcrService() => MobileOcrService();
