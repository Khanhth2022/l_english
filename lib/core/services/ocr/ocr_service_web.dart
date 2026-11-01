import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_service.dart';

/// Gọi bridge JavaScript trong `web/ocr_bridge.js` (Tesseract.js WASM).
extension type _OcrBridge(JSObject _) implements JSObject {
  external JSPromise<JSObject> recognizeBytes(
    JSUint8Array bytes,
    JSFunction onProgress,
  );
}

/// Kết quả thô do bridge trả về, luôn có dạng `{ text, error }`.
extension type _OcrResponse(JSObject _) implements JSObject {
  external String get text;
  external String get error;
}

/// `window.LEnglishOcr` được `web/index.html` nạp trước Flutter.
/// Trả về `null` nếu trang không nạp bridge (ví dụ bản build cũ).
@JS('LEnglishOcr')
external JSObject? get _bridgeObject;

/// OCR cho bản web: Tesseract.js chạy hoàn toàn trong trình duyệt.
///
/// Trước đây bản web dùng stub trả về `null` nên lần quét nào cũng báo
/// "Không tìm thấy văn bản trong ảnh" dù ảnh rất rõ.
class WebOcrService implements OcrService {
  final ImagePicker _picker = ImagePicker();

  @override
  bool get isSupported => _bridgeObject != null;

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
      debugPrint('WebOcrService: chọn ảnh thất bại ($e).');
      return null;
    }
  }

  @override
  Future<OcrResult> extractText(
    XFile image, {
    OcrProgressCallback? onProgress,
  }) async {
    final bridge = _bridgeObject;
    if (bridge == null) {
      return const OcrResult.failed(
        message:
            'Không tìm thấy bộ OCR của trang web (ocr_bridge.js). '
            'Hãy tải lại trang rồi thử lại.',
      );
    }

    final Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (e) {
      return OcrResult.failed(message: 'Không đọc được file ảnh ($e).');
    }
    if (bytes.isEmpty) {
      return const OcrResult.failed(message: 'File ảnh rỗng, không có dữ liệu.');
    }

    onProgress?.call(null, 'Đang nạp bộ nhận diện OCR…');

    try {
      final raw = await _OcrBridge(bridge)
          .recognizeBytes(bytes.toJS, _progressForwarder(onProgress))
          .toDart;
      final response = _OcrResponse(raw);

      final error = response.error.trim();
      if (error.isNotEmpty) {
        return OcrResult.failed(message: error);
      }

      final text = response.text.trim();
      if (text.isEmpty) {
        return const OcrResult.empty(
          message:
              'Ảnh có thể bị mờ, thiếu sáng hoặc không chứa chữ tiếng Anh. '
              'Hãy chụp thẳng trang giấy và đủ sáng.',
        );
      }
      return OcrResult.success(text);
    } catch (e) {
      debugPrint('WebOcrService: OCR thất bại ($e).');
      return OcrResult.failed(message: 'Lỗi OCR trên trình duyệt ($e).');
    }
  }

  /// Chuyển callback Dart thành hàm JS để Tesseract.js báo tiến trình.
  JSFunction _progressForwarder(OcrProgressCallback? onProgress) {
    return ((JSString stage, JSNumber progress) {
      if (onProgress == null) return;
      final double value = progress.toDartDouble;
      final double? percent = (value.isNaN || value < 0)
          ? null
          : value.clamp(0.0, 1.0);
      onProgress(percent, stage.toDart);
    }).toJS;
  }
}

OcrService createOcrService() => WebOcrService();
