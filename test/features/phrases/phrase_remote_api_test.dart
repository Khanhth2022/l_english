import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l_english/features/phrases/data/remote_phrase_api.dart';

/// Kiểm chứng ở mức dây (wire level): `RemotePhraseApi.createPhrase` phải gửi
/// đúng `{"title": ..., "text": ...}` lên `POST /api/phrases` và đọc lại được
/// `title` từ phản hồi của backend.
///
/// File này cố tình KHÔNG dùng `testWidgets`: `TestWidgetsFlutterBinding` chặn
/// toàn bộ HttpClient (mọi request trả 400) nên không thể dựng HTTP server thật.
void main() {
  test('POST /api/phrases gửi kèm title và đọc lại title từ PhraseDto', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    String? rawBody;
    String? requestPath;
    String? contentType;
    server.listen((request) async {
      requestPath = request.uri.path;
      contentType = request.headers.contentType?.mimeType;
      rawBody = await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..write(
          '{"message":"Thêm đoạn văn thành công","data":{"id":7,'
          '"title":"Luyện viết IELTS","text":"This is a long enough sentence.",'
          '"correctedText":"This is a long enough sentence.","score":9,'
          '"createdAt":"2026-01-01T00:00:00Z","errors":[]}}',
        );
      await request.response.close();
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
    final phrase = await RemotePhraseApi(dio)
        .createPhrase('Luyện viết IELTS', 'This is a long enough sentence.');

    expect(requestPath, '/api/phrases');
    expect(contentType, 'application/json');

    final sent = jsonDecode(rawBody!) as Map<String, dynamic>;
    expect(sent['title'], 'Luyện viết IELTS');
    expect(sent['text'], 'This is a long enough sentence.');

    expect(phrase.title, 'Luyện viết IELTS');
    expect(phrase.displayTitle, 'Luyện viết IELTS');
  });

  test('Backend cũ trả PhraseDto không có title → FE hiển thị nhãn mặc định', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        // Phản hồi mô phỏng backend trước commit d92733a: không có khoá title.
        ..write(
          '{"message":"Thêm đoạn văn thành công","data":{"id":8,'
          '"text":"This is a long enough sentence.",'
          '"correctedText":"This is a long enough sentence.","score":9,'
          '"createdAt":"2026-01-01T00:00:00Z","errors":[]}}',
        );
      await request.response.close();
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
    final phrase = await RemotePhraseApi(dio)
        .createPhrase('Luyện viết IELTS', 'This is a long enough sentence.');

    // Đây chính là triệu chứng người dùng báo: dù FE gửi title, response cũ
    // không có title nên UI rơi về "[Không có tiêu đề]".
    expect(phrase.title, isEmpty);
    expect(phrase.displayTitle, '[Không có tiêu đề]');
  });
}
