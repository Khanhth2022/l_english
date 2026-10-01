import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'json_utils.dart';
import 'models/word.dart';
import 'models/word_draft.dart';
import 'models/word_value.dart';
import 'word_api.dart';

/// Gọi backend Spring Boot thật.
class RemoteWordApi implements WordApi {
  RemoteWordApi(this._dio);

  final Dio _dio;

  static const String _basePath = '/api/words';

  @override
  Future<List<Word>> fetchWords() => _call(() async {
    final response = await _dio.get<Object?>(_basePath);
    final data = response.data;
    // Backend có thể trả về mảng trực tiếp, hoặc bọc trong phân trang.
    final list = data is List
        ? data
        : data is Map
        ? (data['content'] ?? data['items'] ?? data['data'])
        : null;
    if (list is! List) {
      throw ApiException(
        0,
        'Máy chủ trả về dữ liệu không đúng định dạng danh sách từ.',
      );
    }
    return asMapList(list).map(Word.fromJson).toList();
  });

  @override
  Future<Word> createWord(WordDraft draft) => _call(() async {
    final response = await _dio.post<Object?>(_basePath, data: draft.toJson());
    return _wordOrThrow(response.data);
  });

  @override
  Future<Word> updateWord(int id, WordDraft draft) => _call(() async {
    final response = await _dio.put<Object?>(
      '$_basePath/$id',
      data: draft.toJson(),
    );
    return _wordOrThrow(response.data);
  });

  @override
  Future<void> deleteWord(int id) => _call(() async {
    await _dio.delete<Object?>('$_basePath/$id');
  });

  @override
  Future<List<WordValue>> generateMeaning(String english) => _call(() async {
    final response = await _dio.get<Object?>(
      '$_basePath/generate',
      queryParameters: {'english': english},
    );
    final data = response.data;
    final list = data is List
        ? data
        : data is Map
        ? (data['values'] ?? data['data'])
        : null;
    if (list is! List) {
      throw ApiException(0, 'Máy chủ không trả về danh sách nghĩa của từ.');
    }
    return asMapList(list).map(WordValue.fromJson).toList();
  });

  @override
  Future<void> confirmReview(List<int> wordIds) => _call(() async {
    await _dio.post<Object?>('$_basePath/review', data: {'wordIds': wordIds});
  });

  Word _wordOrThrow(Object? data) {
    if (data is Map) return Word.fromJson(Map<String, dynamic>.from(data));
    throw ApiException(0, 'Máy chủ không trả về dữ liệu của từ vừa lưu.');
  }

  /// Chuyển lỗi của Dio thành [ApiException] để tầng giao diện chỉ phải xử lý
  /// một loại lỗi duy nhất.
  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapDioException(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(0, 'Không đọc được dữ liệu máy chủ trả về ($error).');
    }
  }
}
