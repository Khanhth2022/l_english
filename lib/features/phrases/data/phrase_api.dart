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

  /// Gửi tiêu đề + văn bản tiếng Anh lên backend, AI chấm điểm rồi lưu cả câu
  /// sửa và lỗi sai.
  ///
  /// [title] là nhãn người dùng đặt cho sổ tay: bắt buộc 1–255 ký tự và chỉ
  /// được lưu, KHÔNG gửi cho AI. Khi người dùng để trống, nơi gọi phải truyền
  /// [Phrase.untitledLabel] vì backend từ chối tiêu đề rỗng.
  Future<Phrase> createPhrase(String title, String text);

  Future<void> deletePhrase(int id);
}
