import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// Chỉ bỏ qua kiểm tra chứng chỉ khi chạy bản debug và kết nối tới máy chủ
/// nội bộ (localhost, emulator, IP LAN) — nơi thường dùng chứng chỉ tự ký.
///
/// Bản release luôn kiểm tra chứng chỉ đầy đủ để tránh bị tấn công MITM.
void configureBypassCertificate(Dio dio) {
  if (!kDebugMode) return;
  if (dio.httpClientAdapter is IOHttpClientAdapter) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) => _isLocalHost(host);
      return client;
    };
  }
}

bool _isLocalHost(String host) {
  final value = host.trim().toLowerCase();
  if (value == 'localhost' ||
      value == '127.0.0.1' ||
      value == '::1' ||
      value == '10.0.2.2') {
    return true;
  }
  if (value.startsWith('192.168.') || value.startsWith('10.')) return true;
  return RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(value);
}
