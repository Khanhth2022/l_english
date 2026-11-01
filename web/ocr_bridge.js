// Cầu nối OCR cho bản web của LEnglish (act-17, seq-17).
//
// Google ML Kit chỉ chạy trên Android/iOS. Trên trình duyệt, Flutter không có
// engine OCR native nào, nên bản web dùng Tesseract.js (WASM) chạy hoàn toàn
// trên máy người dùng (không gửi ảnh lên máy chủ).
//
// File này được nạp trong web/index.html và expose `window.LEnglishOcr`.
// Phía Dart gọi qua `dart:js_interop` trong
// lib/core/services/ocr/ocr_service_web.dart.
(function () {
  'use strict';

  // Ghim phiên bản để CDN không tự đổi API dưới chân ứng dụng.
  var TESSERACT_VERSION = '5.1.1';
  var SCRIPT_URL =
    'https://cdn.jsdelivr.net/npm/tesseract.js@' +
    TESSERACT_VERSION +
    '/dist/tesseract.min.js';
  // Worker phải cùng phiên bản với script chính.
  var WORKER_URL =
    'https://cdn.jsdelivr.net/npm/tesseract.js@' +
    TESSERACT_VERSION +
    '/dist/worker.min.js';
  // Dữ liệu huấn luyện tiếng Anh (~2.9MB, bản best_int nhanh và nhẹ hơn 4.0.0).
  var LANG_PATH =
    'https://cdn.jsdelivr.net/npm/@tesseract.js-data/eng@1.0.0/4.0.0_best_int';

  var scriptPromise = null;
  var workerPromise = null;
  var progressListener = null;

  function reportProgress(status, progress) {
    if (typeof progressListener !== 'function') return;
    try {
      progressListener(String(status || ''), Number(progress));
    } catch (e) {
      // Lỗi callback không được làm hỏng quá trình nhận diện.
      console.warn('[ocr] progress callback lỗi:', e);
    }
  }

  function loadTesseract() {
    if (window.Tesseract) return Promise.resolve(window.Tesseract);
    if (scriptPromise) return scriptPromise;

    scriptPromise = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = SCRIPT_URL;
      script.async = true;
      script.crossOrigin = 'anonymous';
      script.onload = function () {
        if (window.Tesseract) {
          resolve(window.Tesseract);
        } else {
          scriptPromise = null;
          reject(new Error('Tải được thư viện OCR nhưng không khởi tạo được.'));
        }
      };
      script.onerror = function () {
        scriptPromise = null;
        reject(
          new Error(
            'Không tải được thư viện OCR từ CDN. Vui lòng kiểm tra kết nối mạng.'
          )
        );
      };
      document.head.appendChild(script);
    });

    return scriptPromise;
  }

  function getWorker() {
    if (workerPromise) return workerPromise;

    workerPromise = loadTesseract()
      .then(function (Tesseract) {
        return Tesseract.createWorker('eng', 1, {
          workerPath: WORKER_URL,
          langPath: LANG_PATH,
          logger: function (m) {
            if (!m || !m.status) return;
            var p = typeof m.progress === 'number' ? m.progress : -1;
            reportProgress(m.status, p);
          },
        });
      })
      .catch(function (err) {
        // Cho phép lần quét sau thử khởi tạo lại thay vì giữ promise đã hỏng.
        workerPromise = null;
        throw err;
      });

    return workerPromise;
  }

  function bytesToBlob(bytes) {
    if (bytes instanceof Blob) return bytes;
    var view = bytes;
    if (view && view.buffer) {
      view = new Uint8Array(view.buffer, view.byteOffset, view.byteLength);
    }
    return new Blob([view], { type: 'application/octet-stream' });
  }

  /**
   * Nhận diện chữ từ dữ liệu ảnh (Uint8Array).
   * Luôn resolve về { text, error } để phía Dart xử lý thống nhất,
   * không ném exception xuyên qua ranh giới JS/Dart.
   */
  async function recognizeBytes(bytes, onProgress) {
    progressListener = onProgress;
    try {
      if (!bytes || !bytes.length) {
        return { text: '', error: 'Không đọc được dữ liệu ảnh.' };
      }

      reportProgress('Đang nạp bộ nhận diện OCR…', 0);
      var worker = await getWorker();

      reportProgress('Đang đọc chữ trong ảnh…', 0);
      var result = await worker.recognize(bytesToBlob(bytes), {
        rotateAuto: true,
      });

      var text =
        (result && result.data && result.data.text ? result.data.text : '')
          .replace(/\r\n/g, '\n')
          .trim();

      reportProgress('Hoàn tất', 1);
      return { text: text, error: '' };
    } catch (err) {
      var message =
        err && err.message ? String(err.message) : String(err || 'Lỗi không xác định.');
      console.error('[ocr] nhận diện thất bại:', err);
      return { text: '', error: message };
    } finally {
      progressListener = null;
    }
  }

  /** Giải phóng worker OCR (gọi khi không còn dùng để trả lại RAM). */
  async function dispose() {
    if (!workerPromise) return;
    try {
      var worker = await workerPromise;
      await worker.terminate();
    } catch (e) {
      console.warn('[ocr] terminate lỗi:', e);
    } finally {
      workerPromise = null;
    }
  }

  window.LEnglishOcr = {
    version: '1.0.0',
    recognizeBytes: recognizeBytes,
    dispose: dispose,
  };

  // Warm-up tuỳ chọn: nạp trước thư viện để lần quét đầu không phải chờ.
  if (typeof window.LEnglishOcrWarmup === 'undefined') {
    window.LEnglishOcrWarmup = function () {
      return loadTesseract().catch(function () {});
    };
  }
})();
