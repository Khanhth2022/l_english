import 'models/word.dart';
import 'models/word_draft.dart';
import 'models/word_value.dart';

/// Hợp đồng dữ liệu của chức năng Quản lý từ, bám theo tài liệu thiết kế:
///
/// | Thao tác         | Endpoint                     |
/// |------------------|------------------------------|
/// | Xem danh sách từ | `GET /api/words`             |
/// | Thêm từ          | `POST /api/words`            |
/// | Sửa từ           | `PUT /api/words/{id}`        |
/// | Xóa từ           | `DELETE /api/words/{id}`     |
/// | Sinh nghĩa (AI)  | `GET /api/words/generate`    |
/// | Xác nhận ôn tập  | `POST /api/words/review`     |
///
/// Có hai bản hiện thực: [RemoteWordApi] gọi backend thật và
/// `MockWordApi` chạy trong bộ nhớ để app hoạt động khi backend chưa xong.
abstract class WordApi {
  /// Toàn bộ từ của người dùng. Tab "Ôn tập" lọc lại ngay trên dữ liệu này.
  Future<List<Word>> fetchWords();

  Future<Word> createWord(WordDraft draft);

  Future<Word> updateWord(int id, WordDraft draft);

  Future<void> deleteWord(int id);

  /// Nhờ AI sinh nghĩa cho [english]; backend tra `word_cache` trước khi gọi AI.
  Future<List<WordValue>> generateMeaning(String english);

  /// Ghi nhận đã ôn các từ trong [wordIds] (backend cập nhật `review_count`,
  /// `next_review` theo giãn cách 1, 2, 4, 7, 15, 30… ngày).
  Future<void> confirmReview(List<int> wordIds);
}
