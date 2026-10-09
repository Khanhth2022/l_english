import 'package:flutter/foundation.dart';

/// Mixin cho [ChangeNotifier] giúp bỏ qua các lệnh gọi [notifyListeners]
/// một cách an toàn sau khi controller đã bị huỷ ([dispose]).
///
/// Ngăn chặn ngoại lệ `A ... was used after being disposed` khi các tác vụ
/// bất đồng bộ (API call, timeout, microtask) hoàn thành sau khi màn hình đã đóng.
mixin SafeChangeNotifier on ChangeNotifier {
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
