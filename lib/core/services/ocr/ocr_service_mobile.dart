import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_service.dart';

/// Triển khai OCR thật sự bằng Google ML Kit Text Recognition on-device (act-17, seq-17).
class MobileOcrService implements OcrService {
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
    // Trên Android và iOS: gọi Google ML Kit Text Recognition (chạy on-device)
    if (Platform.isAndroid || Platform.isIOS) {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final rawText = recognizedText.text.trim();
        if (rawText.isEmpty) {
          return null;
        }
        return rawText;
      } catch (e) {
        debugPrint('Lỗi ML Kit OCR: $e');
        return null;
      } finally {
        await textRecognizer.close();
      }
    }

    // Trên Windows Desktop hoặc môi trường không có Google Play Services
    return null;
  }
}

OcrService createOcrService() => MobileOcrService();
