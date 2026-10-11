# LEnglish — Diagrams (Class + Use Case + Activity)

## Tệp trong thư mục

| Tệp | Mô tả |
|---|---|
| `class-diagram.puml` | **Nguồn class diagram** (đã kiểm chứng render với PlantUML 1.2024.3) |
| `LEnglish_ClassDiagram.png` | Class diagram — ảnh render sẵn (đủ chèn Word/báo cáo) |
| `LEnglish_ClassDiagram.svg` | Class diagram — bản vector, sắc nét ở mọi kích thước |
| `use-case-diagram.puml` | **Nguồn use case diagram** |
| `LEnglish_UseCase.png` | Use case diagram — ảnh render sẵn |
| `LEnglish_UseCase.svg` | Use case diagram — bản vector |
| `activity/act-01…20-*.puml` | **Nguồn 20 activity diagram** — mỗi chức năng 1 file (act-18: tác vụ hệ thống; act-19: xác nhận ôn tập; act-20: thêm từ theo chủ đề) |
| `activity/*.png / *.svg` | Ảnh render sẵn của 19 activity diagram |
| `sequence/seq-01…20-*.puml` | **Nguồn 20 sequence diagram** — mỗi chức năng 1 file, khớp 1-1 với activity |
| `sequence/*.png / *.svg` | Ảnh render sẵn của 19 sequence diagram |
| `package-diagram.puml` | **Nguồn package diagram** backend Spring Boot (gom theo tầng) |
| `LEnglish_PackageDiagram.png / .svg` | Package diagram — ảnh render sẵn |
| `deployment-diagram.puml` | **Nguồn deployment diagram** — node vật lý + giao thức (HTTPS/JDBC) |
| `LEnglish_DeploymentDiagram.png / .svg` | Deployment diagram — ảnh render sẵn |
| `erd-diagram.puml` | **Nguồn ERD** — sơ đồ CSDL (8 bảng, PK/FK, crow's foot; thuộc tính đa trị tách 1–n) |
| `LEnglish_ERD.png / .svg` | ERD — ảnh render sẵn |
| `class-diagram.mmd` | Bản Mermaid tương đương (nếu cần nhúng vào Markdown/GitHub) |

## Xem trước trong VS Code

Extension đã cài: **PlantUML (jebbs)** — mở file `.puml` rồi nhấn `Alt+D`.

- Dòng `!pragma layout smetana` buộc dùng layout engine có sẵn của PlantUML, **không cần cài Graphviz**.
- Nếu máy có Graphviz (`dot`), có thể xóa dòng pragma đó để dot tự sắp bố cục (thường đẹp hơn với diagram lớn).

## Use case — tổng quan

- **Actor chính:** Người dùng (duy nhất).
- **Actor phụ:** AI — thực hiện 3 chức năng (ô màu vàng; *Sinh nghĩa từ* và *Chấm đoạn văn* người dùng không gọi trực tiếp, riêng *Thêm từ theo chủ đề* người dùng bấm nút tạo):
  - *Sinh nghĩa từ* (`<<extend>>` **Thêm từ**): **cache-first** — tra `word_cache` trước, trúng thì trả luôn cho người dùng; cache-miss mới gọi AI sinh nghĩa (đ Anh - Việt) rồi lưu vào `word_cache` (bảng dùng chung, không gắn user). Chạy khi người dùng bấm gợi ý nghĩa trong màn **Thêm từ**.
  - *Chấm đoạn văn*: AI trả về **đủ 5 kết quả** và lưu thẳng vào DB. Được gọi tự động khi **Thêm đoạn văn** qua `<<include>>`:
    | Kết quả AI | Cột lưu |
    |---|---|
    | `score` (0..10) | `phrases.score` |
    | `correctedText` (câu đã sửa hoàn chỉnh) | `phrases.corrected_text` |
    | `error` (cụm sai) | `grammar_errors.incorrect` |
    | `correction` (cụm đúng) | `grammar_errors.correction` |
    | `explanation` (giải thích tiếng Việt) | `grammar_errors.explanation` |
  - *Thêm từ theo chủ đề*: người dùng nhập **một chủ đề** → AI xác nhận input có phải chủ đề có nghĩa (không → **400** "vui lòng nhập lại") → lấy danh sách từ đã có của user làm **danh sách loại trừ** → AI sinh **10 từ mới** kèm đầy đủ nghĩa → mỗi từ: cache-miss thì ghi `word_cache` + `word_cache_values`, luôn ghi `words` + `word_values` gắn user (1 transaction, trùng `UNIQUE (user_id, english)` → rollback cả batch). AI lỗi → **502**, không ghi DB. Luồng: act-20 / seq-20.
- **Actor phụ:** Bộ định thời (hệ thống) — tác vụ nền chạy trên **server**, mỗi ngày vào một khung giờ cố định **dọn (xóa) các refresh token đã hết hạn** khỏi DB. Không do người dùng gọi.
- **3 nhóm chức năng:**
  1. *Quản lý tài khoản*: Đăng nhập, Đăng xuất, Tạo tài khoản + **Làm mới token** (client tự động gọi khi access token hết hạn — refresh token rotation) + **Dọn refresh token hết hạn** (Bộ định thời chạy trên server, định kỳ mỗi ngày).
  2. *Quản lý từ*: Xem, Thêm, Sửa, Xóa + **Ôn tập từ vựng** (tab lọc phía client trên dữ liệu Xem từ, không có luồng server riêng) + **Xác nhận ôn tập** (cập nhật SRS) + **Sinh nghĩa từ** (AI) + **Thêm từ theo chủ đề** (AI sinh 10 từ mới không trùng sổ).
  3. *Quản lý đoạn văn*: Xem, **Thêm đoạn văn** (gộp: gọi Chấm đoạn văn AI → lưu DB → trả kết quả cho người dùng), Xóa + **Chấm đoạn văn** (AI, người dùng không gọi trực tiếp).
- **Điều kiện tiên quyết:** phải Đăng nhập trước khi dùng các chức năng Quản lý từ / Quản lý đoạn văn.
- **Làm mới token:** do **client** tự động gọi khi access token hết hạn (KHÔNG phải bộ định thời). Refresh token rotation: refresh token gửi lên còn trong DB và **còn hạn** → cấp cặp token mới và **xóa refresh token cũ**; nếu **không có trong DB** hoặc **đã hết hạn** → **xóa token** (nếu có) và **yêu cầu đăng nhập lại**, không cấp token mới. Luồng chi tiết: seq-04 / act-04.
- **Dọn refresh token hết hạn:** **Bộ định thời** chạy trên **server**, mỗi ngày vào khung giờ cố định xóa các refresh token có `expiry_date` đã qua. Luồng: seq-18 / act-18. (Làm mới token dọn token hết hạn *theo yêu cầu*; tác vụ này dọn *định kỳ* để không tồn token chết trong DB.)

## Class diagram — tóm tắt mô hình

| Class | Bảng | Ghi chú |
|---|---|---|
| `User` | `users` | `username` UNIQUE NOT NULL; `password` lưu **BCrypt hash** (60 ký tự), không plain text |
| `Word` | `words` | từ vựng của 1 User; `english` **NOT NULL** + **UNIQUE `(user_id, english)`** (mỗi user không có từ trùng, nhưng 2 user khác nhau vẫn được có cùng từ); SRS: `reviewCount` (default 0) + `nextReview` — cập nhật khi **Xác nhận ôn tập** (seq-19); tab **Ôn tập** chỉ lọc `nextReview <= now` phía client (không truy vấn riêng); index gợi ý `(user_id, nextReview)` |
| `WordValue` | `word_values` | thuộc tính đa trị của Word tách sang bảng riêng: `vietnamese`, `example`, `exampleTranslation`, `pronunciation`, `partOfSpeech`; FK `word_id`, cascade |
| `Phrase` | `phrases` | câu gốc + câu đã sửa; `score` CHECK 0..10 — do **AI chấm** khi Thêm đoạn văn; `createdAt`/`updatedAt` |
| `GrammarError` | `grammar_errors` | cụm sai/cụm đúng/giải thích tiếng Việt, FK về `phrases` — do **AI sinh** cùng lúc với score |
| `RefreshToken` | `refresh_tokens` | `token` String/VARCHAR UNIQUE NOT NULL, `expiryDate` NOT NULL, `createdAt`; FK `user_id` NOT NULL, index `(user_id)`. Token hết hạn được xóa (logout/refresh/dọn định kỳ), không dùng cột trạng thái |
| `WordCache` | `word_cache` | **chỉ chứa thông tin từ** (`english` UNIQUE, `level`), **KHÔNG có `user_id`** nên dùng chung cho mọi user; cũng **không** có `reviewCount`/`nextReview` — trạng thái SRS chỉ thuộc `words` (theo từng user) |
| `WordCacheValue` | `word_cache_values` | thuộc tính đa trị của WordCache: `vietnamese`, `example`, `exampleTranslation`, `pronunciation`, `partOfSpeech`; FK `word_cache_id`, cascade |
| `Level` | — | enum `A1..C2`, map bằng `@Enumerated(EnumType.STRING)` |
| `PartOfSpeech` | `word_values.part_of_speech`, `word_cache_values.part_of_speech` | enum 8 giá trị: `NOUN, VERB, ADJECTIVE, ADVERB, PREPOSITION, CONJUNCTION, PRONOUN, INTERJECTION`; map `@Enumerated(EnumType.STRING)` |

## Quan hệ

- `User 1 --- 0..* Word` (cascade ALL + orphanRemoval)
- `User 1 --- 0..* Phrase` (cascade ALL + orphanRemoval)
- `User 1 --- 0..* RefreshToken` (xóa User → xóa token)
- `Phrase 1 *--- 0..* GrammarError` (composition: lỗi sai là thành phần của Phrase)
- `Word 1 *--- 0..* WordValue` (composition: thuộc tính đa trị, cascade + orphanRemoval)
- `WordCache 1 *--- 0..* WordCacheValue` (composition, cascade + orphanRemoval)
- `Word / WordCache ..> Level` (dependency, dùng enum)
- `WordValue / WordCacheValue ..> PartOfSpeech` (dependency, dùng enum)

## Activity diagrams — 20 sơ đồ (19 chức năng + 1 tác vụ hệ thống)

| File | Chức năng | Nhóm |
|---|---|---|
| `act-01-dang-ky` | Tạo tài khoản | Tài khoản |
| `act-02-dang-nhap` | Đăng nhập | Tài khoản |
| `act-03-dang-xuat` | Đăng xuất | Tài khoản |
| `act-04-lam-moi-token` | Làm mới token (hệ thống) | Tài khoản |
| `act-05-xem-tu` | Xem từ | Từ |
| `act-06-them-tu` | Thêm từ | Từ |
| `act-07-sua-tu` | Sửa từ | Từ |
| `act-08-xoa-tu` | Xóa từ | Từ |
| `act-09-sinh-nghia-tu` | Sinh nghĩa từ (AI) | Từ |
| `act-10-xem-doan-van` | Xem đoạn văn | Đoạn văn |
| `act-11-them-doan-van` | Thêm đoạn văn | Đoạn văn |
| `act-12-cham-doan-van` | Chấm đoạn văn (AI, hàm nội bộ) | Đoạn văn |
| `act-13-xoa-doan-van` | Xóa đoạn văn | Đoạn văn |
| `act-14-thong-bao-on-tap` | Thông báo ôn tập (Android) | Android |
| `act-15-widget-man-hinh-chinh` | Widget màn hình chính (Android) | Android |
| `act-16-them-tu-tu-bo-chon` | Thêm từ từ văn bản bôi đen (Android) | Android |
| `act-17-scan-ocr-doan-van` | Quét OCR lấy văn bản vào ô Chấm đoạn văn | Android |
| `act-18-don-refresh-token` | Dọn refresh token hết hạn (server, định kỳ) | Tài khoản |
| `act-19-xac-nhan-on-tap` | Xác nhận ôn tập → cập nhật SRS (review_count, next_review) | Từ |
| `act-20-them-tu-theo-chu-de` | Thêm từ mới theo chủ đề — AI duyệt chủ đề, loại trừ trùng, sinh 10 từ + ghi cache | Từ |

Quy ước chung: hoạt động màu **xanh nhạt** = xử lý chính; ô quyết định màu **vàng**; nhánh trả lỗi (400/401/403/409) tô **đỏ nhạt**.

## Sequence diagrams — 20 sơ đồ (19 chức năng + 1 tác vụ hệ thống)

Mỗi activity diagram có một sequence diagram tương ứng trong thư mục `sequence/` (khớp 1-1 theo số thứ tự và tên chức năng). Activity mô tả *luồng xử lý* (làm gì, rẽ nhánh ra sao); sequence mô tả *ai gọi ai theo thời gian* qua các tầng của kiến trúc.

| File | Chức năng | Lifelines chính |
|---|---|---|
| `seq-01-dang-ky` | Tạo tài khoản | User · UI · AuthController · UserService · UserRepository · DB |
| `seq-02-dang-nhap` | Đăng nhập | User · UI · AuthController · AuthService · User/RefreshTokenRepository · DB |
| `seq-03-dang-xuat` | Đăng xuất | User · UI · AuthController · AuthService · RefreshTokenRepository · DB |
| `seq-04-lam-moi-token` | Làm mới token (rotation) | UI · AuthController · AuthService · RefreshTokenRepository · DB |
| `seq-05-xem-tu` | Xem từ | User · UI · **JwtFilter** · WordController · WordService · WordRepository · DB |
| `seq-06-them-tu` | Thêm từ | (như trên) |
| `seq-07-sua-tu` | Sửa từ (403 sở hữu + 409 trùng) | (như trên) |
| `seq-08-xoa-tu` | Xóa từ (403 sở hữu) | (như trên) |
| `seq-09-sinh-nghia-tu` | Sinh nghĩa từ (AI, cache-first) | + WordCacheRepository · **AI** |
| `seq-10-xem-doan-van` | Xem đoạn văn | User · UI · JwtFilter · PhraseController · PhraseService · PhraseRepository · DB |
| `seq-11-them-doan-van` | Thêm đoạn văn (`ref` → seq-12) | + **AI** |
| `seq-12-cham-doan-van` | Chấm đoạn văn (AI, hàm nội bộ) | PhraseService · GradingService · **AI** |
| `seq-13-xoa-doan-van` | Xóa đoạn văn (cascade) | (như seq-10) |
| `seq-14-thong-bao-on-tap` | Thông báo ôn tập (Android) | User · App · WorkManager · Worker · Backend API · NotificationManager |
| `seq-15-widget-man-hinh-chinh` | Widget màn hình chính (Android) | User · Launcher · AppWidgetProvider · Backend API · App |
| `seq-16-them-tu-tu-bo-chon` | Thêm từ từ bôi đen (Android) | User · Android OS · Màn Thêm từ · AI · Backend API |
| `seq-17-scan-ocr-doan-van` | Quét OCR lấy văn bản (Android, chỉ dùng cho Chấm đoạn văn) | User · App · Android OS · ML Kit OCR · Backend API |
| `seq-18-don-refresh-token` | Dọn refresh token hết hạn (server) | Bộ định thời (@Scheduled) · TokenCleanupService · RefreshTokenRepository · DB |
| `seq-19-xac-nhan-on-tap` | Xác nhận ôn tập — POST /api/words/review (cập nhật SRS) | User · UI · JwtFilter · WordController · WordService · WordRepository · DB |
| `seq-20-them-tu-theo-chu-de` | Thêm từ mới theo chủ đề — AI duyệt chủ đề, loại trừ trùng, sinh 10 từ | User · UI · JwtFilter · WordController · WordService · WordRepository · WordCacheRepository · DB · AI |

Quy ước sequence diagram (theo UML chuẩn, đúng kiểu dùng trong báo cáo):

- **Thứ tự lifeline trái→phải theo chiều gọi**: actor (Người dùng) → boundary (Giao diện/Client) → control (Controller) → business (Service) → data (Repository) → `database` (DB) → hệ thống ngoài (AI) ở ngoài cùng. Bố cục này khớp đúng 4 tầng của package diagram.
- **Mũi tên liền đầu đặc** = lời gọi đồng bộ; **mũi tên đứt** = giá trị trả về/đáp ứng. Nhãn ghi tên thao tác + tham số/HTTP method.
- **Thanh kích hoạt (activation bar)** thể hiện khoảng thời gian một lifeline đang xử lý.
- **Khối `alt` / `opt` / `loop`** cho rẽ nhánh — điều kiện đặt trong `[dấu ngoặc]`; đây là cách map các `if/else` của activity sang sequence. Các nhánh lỗi 400/401/403/409 nằm trong nhánh `alt` tương ứng.
- **`ref`** (interaction occurrence) để tái dùng một tương tác: seq-11 tham chiếu seq-12 đúng theo quan hệ «include».
- **`autonumber`** đánh số thứ tự message để dễ trích dẫn trong thuyết minh.
- **JwtFilter** («config») là cổng xác thực token đứng trước Controller ở mọi chức năng cần đăng nhập — đúng với gạch phụ thuộc `Config ..> Controller` trong package diagram.

Render: giống các diagram khác — mở `.puml` trong VS Code rồi `Alt+D`. Sequence diagram không cần Graphviz (PlantUML tự vẽ), nên **không có** dòng `!pragma layout`.

## Deployment diagram — kiến trúc triển khai

Góc nhìn vật lý (bổ sung cho các diagram logic). Bốn node: **Thiết bị Android** (chứa `LEnglish.apk` — UI, WorkManager/Worker, AppWidgetProvider, ML Kit OCR), **Máy chủ ứng dụng** (`lenglish-backend.jar` — Controller, JwtFilter, Service, Repository), **Máy chủ CSDL** (MySQL), và **Dịch vụ AI bên ngoài**. Đường giao tiếp kèm giao thức: app → backend qua **HTTPS/REST + JWT**; backend → CSDL qua **JDBC**; backend → AI qua **HTTPS/REST + API key**. Ghi chú: **OCR chạy on-device**, không gửi ảnh ra mạng.

## ERD — sơ đồ cơ sở dữ liệu

Suy ra từ các JPA Entity, thể hiện góc nhìn *bảng thật*. Tám bảng: `users`, `words`, `word_values`, `word_cache`, `word_cache_values`, `phrases`, `grammar_errors`, `refresh_tokens` với PK/FK, ràng buộc **UNIQUE** (`users.username`, `word_cache.english`, `refresh_tokens.token`, và **tổ hợp** `words(user_id, english)`), **CHECK** (`phrases.score` 0..10) và quan hệ crow's foot (`||--o{`). `grammar_errors` phụ thuộc `phrases` theo **ON DELETE CASCADE** (khớp composition + orphanRemoval). `word_cache` **không có** `user_id` (cache dùng chung).

Thuộc tính đa trị (`@ElementCollection`: vietnamese, example, example_translation, pronunciation, part_of_speech) được **chuẩn hoá 1NF**: `words` 1–n `word_values`, `word_cache` 1–n `word_cache_values`. Mỗi bảng con có FK chủ + **năm cột riêng, mỗi thuộc tính một cột**: `vietnamese`, `example`, `example_translation`, `pronunciation`, `part_of_speech` (`part_of_speech` lưu tên enum `PartOfSpeech`, viết bằng chữ thường dạng `snake_case`). Cách này thay cho việc gộp chung cặp `kind`/`value`. Cả hai quan hệ đều **ON DELETE CASCADE**.

## Rà soát luồng theo chuẩn quốc tế

Luồng bạn mô tả đã đúng tinh thần REST + JWT thông dụng. Các điểm tôi đã bổ sung/khiến chắc khi vẽ:

1. **Tạo tài khoản** — thêm bước *kiểm tra username đã tồn tại* (trả 409) trước khi insert, và *hash BCrypt* trước khi lưu. Không có bước này, lỗi `UNIQUE` của DB sẽ rơi ra 500 thay vì lỗi nghiệp vụ sạch.
2. **Đăng nhập** — so khớp mật khẩu qua BCrypt, và *lưu refresh token vào `refresh_tokens` kèm `expiryDate`* trước khi trả cặp token. Đúng chuẩn OAuth2/JWT.
3. **Làm mới token** — luồng của bạn chính là **refresh token rotation** (best practice hiện đại: dùng rồi xóa, cấp cặp mới). Đã thêm *kiểm tra `expiryDate`*: token còn nằm trong DB nhưng đã hết hạn → vẫn phải 401 và xóa token chết đi.
4. **Đăng xuất** — đúng. Kèm ghi chú: access token (JWT) không thu hồi ngay mà sống đến khi hết hạn (stateless) — vì vậy access token phải *ngắn hạn* (15–60 phút).
5. **Xem từ / Xem đoạn văn** — truy vấn luôn lọc `WHERE user_id = user hiện tại`: mỗi user chỉ thấy dữ liệu của mình, khớp mô hình `User 1-n Word/Phrase`.
6. **Thêm từ** — use case chính: nhận thông tin từ form gửi lên → *kiểm tra từ đã tồn tại trong sổ của user chưa* (ràng buộc **UNIQUE `(user_id, english)`**; trùng → trả **409** thay vì để DB ném 500) → lưu DB (gắn `user_id`). Use case **Sinh nghĩa từ** là `<<extend>>` của Thêm từ (người dùng bấm gợi ý nghĩa mới chạy): tra `word_cache` trước, chỉ cache-miss mới gọi AI — khớp `UNIQUE(english)` thiết kế sẵn ở bảng cache dùng chung.
7. **Sửa/Xóa từ, Xóa đoạn văn** — có bước kiểm tra **sở hữu** (403) như bạn viết — đúng chuẩn, chống IDOR (sửa/xóa tài nguyên của người khác). Riêng **Sửa từ** còn thêm guard trùng `UNIQUE (user_id, english)` → **409** khi đổi `english` sang từ đã có trong sổ (tránh DB ném 500), và đồng bộ **danh sách** `word_values` trong cùng transaction với `words`: 1 từ có **nhiều** nghĩa (mỗi nghĩa 1 dòng đủ 5 thuộc tính) → sửa dòng cũ theo id, thêm dòng mới, xóa dòng bị bỏ (orphanRemoval).
8. **Thêm đoạn văn** — thêm bước gọi *Chấm đoạn văn* (`<<include>>` như use case diagram) rồi mới lưu `Phrase` + `GrammarErrors`, vì `score`/`correctedText`/lỗi sai đều do AI sinh ra; chấm thất bại thì **không lưu**.
9. **Chấm đoạn văn** — **hàm nội bộ**, người dùng KHÔNG gọi trực tiếp: validate là đoạn văn hợp lệ (sai → **400**) → AI trả 5 kết quả (score, correctedText, error, correction, explanation) → AI lỗi/timeout → **502**. Được Thêm đoạn văn gọi lại qua «include». Sinh nghĩa từ dùng cùng quy ước mã lỗi: từ không phải tiếng Anh → **400**, AI lỗi → **502**.
10. **Ôn tập từ vựng** — **không phải use case gọi server riêng**. Về phía app: khi người dùng bấm tab Từ vựng thì đã tải toàn bộ từ (Xem từ); tab Ôn tập chỉ **lọc lại trên dữ liệu đã tải** (giữ các từ có `next_review <= now`). Vì thế không có API/act/seq riêng — chỉ là một biến thể hiển thị (`<<extend>>` của Xem từ trong use case diagram).
11. **Xác nhận ôn tập** — đây mới là chức năng gọi server. Người dùng gửi danh sách `wordIds` đã ôn (`POST /api/words/review`). Server kiểm tra token + **sở hữu** (mọi `wordId` phải thuộc user, sai → 403 chống IDOR), rồi với mỗi từ: `review_count += 1`, tính khoảng cách ôn kế tiếp **giãn dần theo số lần đã ôn** (spaced repetition: 1, 2, 4, 7, 15, 30… ngày), đặt `next_review = now() + khoảng cách`, lưu batch. Đây là luồng duy nhất ghi vào các cột SRS `review_count`/`next_review`. Luồng: act-19 / seq-19.

12. **Thêm từ mới theo chủ đề** — chức năng AI mới (act-20 / seq-20). Người dùng nhập **một chủ đề** (vd. "công sở"): JWT sai/hết hạn → **401**; AI xác nhận input có phải chủ đề có nghĩa hay chỉ là một từ rời vô nghĩa (vô nghĩa → **400** "Chủ đề không hợp lệ, vui lòng nhập lại"); hợp lệ thì lấy toàn bộ `english` trong sổ của user gửi sang AI làm **danh sách loại trừ**; AI sinh **10 từ mới** kèm nghĩa, phiên âm, từ loại, ví dụ, level; server ghi từng từ vào `word_cache` + `word_cache_values` (chỉ khi cache-miss) và `words` + `word_values` gắn user — toàn bộ trong **một transaction**, vi phạm `UNIQUE (user_id, english)` → rollback cả batch; AI lỗi/timeout → **502**, không ghi DB.