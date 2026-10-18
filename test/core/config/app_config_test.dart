import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/core/config/app_config.dart';

void main() {
  group('AppConfig.normalizeUrl', () {
    test('thêm https:// cho domain thông thường nếu thiếu giao thức', () {
      expect(
        AppConfig.normalizeUrl('stewart-resource-busy-bristol.trycloudflare.com'),
        'https://stewart-resource-busy-bristol.trycloudflare.com',
      );
    });

    test('thêm http:// cho localhost và địa chỉ IP', () {
      expect(
        AppConfig.normalizeUrl('localhost:8080'),
        'http://localhost:8080',
      );
      expect(
        AppConfig.normalizeUrl('10.0.2.2:8080'),
        'http://10.0.2.2:8080',
      );
      expect(
        AppConfig.normalizeUrl('192.168.1.15:8080'),
        'http://192.168.1.15:8080',
      );
    });

    test('loại bỏ dấu gạch chéo cuối trang', () {
      expect(
        AppConfig.normalizeUrl('https://example.com/'),
        'https://example.com',
      );
      expect(
        AppConfig.normalizeUrl('http://10.0.2.2:8080///'),
        'http://10.0.2.2:8080',
      );
    });

    test('loại bỏ hậu tố /api nếu người dùng dán kèm', () {
      expect(
        AppConfig.normalizeUrl('https://example.com/api'),
        'https://example.com',
      );
      expect(
        AppConfig.normalizeUrl('https://example.com/api/'),
        'https://example.com',
      );
      expect(
        AppConfig.normalizeUrl('http://10.0.2.2:8080/api'),
        'http://10.0.2.2:8080',
      );
    });

    test('cắt bỏ khoảng trắng thừa ở hai đầu', () {
      expect(
        AppConfig.normalizeUrl('   https://stewart-resource-busy-bristol.trycloudflare.com/   '),
        'https://stewart-resource-busy-bristol.trycloudflare.com',
      );
    });
  });

  group('AppConfig.setApiBaseUrl', () {
    test('chuẩn hoá và cập nhật apiBaseUrl và dio.options.baseUrl', () {
      final dio = Dio(BaseOptions(baseUrl: 'http://old.com'));
      AppConfig.setApiBaseUrl('https://stewart-resource-busy-bristol.trycloudflare.com/api/', dio);

      expect(AppConfig.apiBaseUrl, 'https://stewart-resource-busy-bristol.trycloudflare.com');
      expect(dio.options.baseUrl, 'https://stewart-resource-busy-bristol.trycloudflare.com');
    });
  });

  group('AppConfig.testConnection', () {
    test('trả về lỗi khi URL rỗng hoặc sai', () async {
      final result = await AppConfig.testConnection('');
      expect(result.isSuccess, isFalse);
    });

    test('kết nối thành công tới máy chủ Cloudflare thực tế', () async {
      final result = await AppConfig.testConnection(
        'https://stewart-resource-busy-bristol.trycloudflare.com',
        timeout: const Duration(seconds: 8),
      );
      expect(result.isSuccess, isTrue);
      expect(result.latencyMs, isNotNull);
      expect(result.latencyMs! > 0, isTrue);
    }, skip: 'Cloudflare tunnel tạm thời có thể hết hạn');
  });
}
