import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Cho phép thiết bị di động (Android / iOS) và máy tính kết nối tới máy chủ thử nghiệm
/// (Cloudflare Tunnel, Self-signed SSL, local IP) mà không bị lỗi handshake chứng chỉ.
void configureBypassCertificate(Dio dio) {
  if (dio.httpClientAdapter is IOHttpClientAdapter) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };
  }
}
