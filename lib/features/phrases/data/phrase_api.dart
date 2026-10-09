import 'models/phrase_models.dart';

/// Hợp đồng API cho phân hệ Quản lý đoạn văn (Phrases) theo tài liệu thiết kế:
///
/// | Thao tác            | Endpoint                 |
/// |---------------------|--------------------------|
/// | Danh sách đoạn văn  | `GET /api/phrases`       |
/// | Chấm điểm & lưu     | `POST /api/phrases`      |
/// | Xóa đoạn văn        | `DELETE /api/phrases/{id}`|
abstract class PhraseApi {
  Future<List<Phrase>> fetchPhrases();

  /// Gửi văn bản tiếng Anh lên backend, AI chấm điểm rồi lưu cả câu sửa và lỗi sai.
  Future<Phrase> createPhrase(String text);

  Future<void> deletePhrase(int id);
}
