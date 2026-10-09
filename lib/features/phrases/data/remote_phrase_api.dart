import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../features/words/data/json_utils.dart';
import 'models/phrase_models.dart';
import 'phrase_api.dart';

/// Gọi trực tiếp API Quản lý đoạn văn của Spring Boot backend.
class RemotePhraseApi implements PhraseApi {
  RemotePhraseApi(this._dio);

  final Dio _dio;
  static const String _basePath = '/api/phrases';

  @override
  Future<List<Phrase>> fetchPhrases() => _call(() async {
        final response = await _dio.get<Object?>(_basePath);
        final data = response.data;
        final list = data is List
            ? data
            : data is Map
                ? (data['content'] ?? data['items'] ?? data['data'])
                : null;
        if (list is! List) {
          throw ApiException(0, 'Máy chủ trả về dữ liệu không đúng danh sách đoạn văn.');
        }
        return asMapList(list).map(Phrase.fromJson).toList();
      });

  @override
  Future<Phrase> createPhrase(String text) => _call(() async {
        final response = await _dio.post<Object?>(
          _basePath,
          data: {'text': text},
        );
        final data = response.data;
        final phraseMap = data is Map
            ? (data['data'] is Map ? data['data'] : data)
            : null;
        if (phraseMap is Map) {
          return Phrase.fromJson(Map<String, dynamic>.from(phraseMap));
        }
        throw ApiException(0, 'Máy chủ không trả về kết quả chấm đoạn văn.');
      });

  @override
  Future<void> deletePhrase(int id) => _call(() async {
        await _dio.delete<Object?>('$_basePath/$id');
      });

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw mapDioException(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(0, 'Lỗi kết nối máy chủ ($error).');
    }
  }
}
