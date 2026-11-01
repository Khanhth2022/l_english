import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:l_english/core/services/ocr/ocr_service.dart';

void main() {
  group('OcrResult', () {
    test('success có văn bản thì hasText = true', () {
      const result = OcrResult.success('Hello world');

      expect(result.status, OcrStatus.success);
      expect(result.text, 'Hello world');
      expect(result.hasText, isTrue);
      expect(result.message, isNull);
    });

    test('chuỗi chỉ có khoảng trắng không được coi là có văn bản', () {
      expect(const OcrResult.success('   \n  ').hasText, isFalse);
    });

    test('empty / unsupported / failed đều không có text', () {
      const empty = OcrResult.empty(message: 'không có chữ');
      const unsupported = OcrResult.unsupported();
      const failed = OcrResult.failed(message: 'mất mạng');

      expect(empty.status, OcrStatus.empty);
      expect(unsupported.status, OcrStatus.unsupported);
      expect(failed.status, OcrStatus.failed);

      expect(empty.text, isNull);
      expect(unsupported.text, isNull);
      expect(failed.text, isNull);

      expect(empty.hasText, isFalse);
      expect(unsupported.hasText, isFalse);
      expect(failed.hasText, isFalse);
    });
  });

  test(
    'OcrService trên nền tảng không có ML Kit trả về unsupported (không phải null)',
    () async {
      final service = OcrService();
      final result = await service.extractText(XFile('dummy.png'));

      // Trên máy chạy test (Windows/Linux/macOS) không có ML Kit, nhưng UI phải
      // phân biệt được "không hỗ trợ" với "ảnh không có chữ".
      expect(result.status, OcrStatus.unsupported);
      expect(result.message, isNotNull);
      expect(result.hasText, isFalse);
    },
  );
}
