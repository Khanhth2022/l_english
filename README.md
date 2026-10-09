# 📘 LEnglish — Ứng dụng Học Từ Vựng Thông Minh & Luyện Viết Cùng AI

> **Phiên bản:** `1.0.0` • **Nền tảng:** Flutter (Dart ^3.13) / Android  
> **Kiến trúc:** Feature-First, Repository Pattern, MultiProvider  
> **Backend tương thích:** Spring Boot (REST API, JWT Bearer, MySQL 8 bảng)

---

## 🌟 1. Giới thiệu tổng quan

**LEnglish** là giải pháp hỗ trợ người học tiếng Anh toàn diện, kết hợp giữa phương pháp ghi nhớ khoa học và trí tuệ nhân tạo (AI):
* 📖 **Ghi nhớ từ vựng qua Spaced Repetition (SRS):** Tự động lên lịch giãn cách ôn tập (1, 2, 4, 7, 15, 30 ngày) dựa trên số lần ôn thực tế, tối ưu hóa khả năng ghi nhớ dài hạn vào vỏ não.
* 🤖 **Tra cứu & Sinh nghĩa từ bằng AI (Cache-First):** AI tự động phân tích từ vựng, trích xuất CEFR Level (A1–C2), phiên âm IPA, từ loại, nghĩa tiếng Việt và ví dụ ngữ cảnh; cơ chế cache dùng chung giúp tối ưu tốc độ và giảm chi phí gọi AI.
* 💡 **Đề xuất từ vựng theo chủ đề (AI Topic Generator):** Người dùng chỉ cần nhập chủ đề (công sở, du lịch, công nghệ...), AI tự động loại trừ các từ đã có trong sổ và sinh 10 từ mới chất lượng cao để nạp nhanh vào sổ từ.
* ✍️ **Luyện viết & Chấm điểm ngữ pháp bằng AI:** Nhận diện và bóc tách câu văn tiếng Anh (10–5000 ký tự), chấm điểm trên thang 10, chỉ ra từng cụm từ sai ngữ pháp, cung cấp câu sửa chuẩn hoàn chỉnh và giải thích chi tiết bằng tiếng Việt.
* 📱 **Tích hợp sâu hệ điều hành Android:** Mô phỏng widget màn hình chính hiển thị số từ đến hạn ôn tập, thông báo nhắc nhở định kỳ (WorkManager), quét OCR trích xuất chữ từ ảnh/sách vào ô chấm bài (ML Kit), và tiện ích bôi đen từ vựng tra cứu nhanh (`PROCESS_TEXT`).

---

## 🏗️ 2. Kiến trúc & Cấu trúc thư mục (Dành cho Dev & AI Agent)

Dự án được tổ chức theo mô hình **Feature-First (Phân hệ độc lập)** kết hợp **Layered Architecture (Tầng dữ liệu - Trạng thái - Giao diện)**:

```text
lib/
├── core/                           # Thành phần dùng chung toàn ứng dụng
│   ├── auth/                       # Quản lý Token và Session phiên đăng nhập
│   │   └── token_store.dart        # Contract TokenStore & InMemoryTokenStore (hỗ trợ secure storage)
│   ├── config/                     # Cấu hình môi trường chạy (AppConfig, baseUrl, cờ Mock)
│   ├── network/                    # Tầng mạng REST API (Dio)
│   │   ├── api_client.dart         # Cấu hình Dio Client, timeout, Base URL
│   │   ├── api_exception.dart      # Chuẩn hóa lỗi HTTP (400, 401, 403, 409, 502, 500)
│   │   └── auth_interceptor.dart   # Gắn Bearer JWT, tự bắt 401 xoay vòng Refresh Token (single-flight)
│   ├── theme/                      # Design System Material 3 hiện đại
│   │   └── app_theme.dart          # Bảng màu Blue/Emerald/Violet AI, Card, Typography, Button
│   ├── ui/                         # Các widget trạng thái tái sử dụng (Loading, Error, Empty View)
│   └── utils/                      # Tiện ích định dạng thời gian, format dữ liệu
│
├── features/                       # Các phân hệ nghiệp vụ chính (Features)
│   │
│   ├── auth/                       # [Phân hệ 1] Quản lý tài khoản (act-01 đến act-04)
│   │   ├── data/                   # Models DTO (AuthResponse), AuthApi, Remote & Mock Auth API
│   │   ├── state/                  # AuthController (quản lý login, register, logout, notify)
│   │   └── ui/                     # AuthScreen (form đăng nhập/đăng ký), ProfileScreen (thông tin phiên)
│   │
│   ├── words/                      # [Phân hệ 2] Quản lý từ vựng & SRS (act-05..09, 19, 20)
│   │   ├── data/                   # Models (Word, WordValue, WordDraft, Level, PartOfSpeech)
│   │   │   ├── word_api.dart       # Contract WordApi (CRUD từ, generate AI, SRS, topic words)
│   │   │   ├── remote_word_api.dart# Gọi trực tiếp Spring Boot REST endpoints
│   │   │   └── mock_word_api.dart  # Mock in-memory đầy đủ thuật toán SRS, cache-first, mã lỗi
│   │   ├── state/                  # WordListController, WordFormController
│   │   └── ui/                     # WordListScreen (Tab Tất cả & Ôn tập), WordFormScreen, TopicWordsScreen
│   │
│   ├── phrases/                    # [Phân hệ 3] Quản lý đoạn văn & Chấm AI (act-10 đến act-13)
│   │   ├── data/                   # Models (Phrase, GrammarError), PhraseApi, Remote & Mock Phrase API
│   │   ├── state/                  # PhraseListController, PhraseFormController
│   │   └── ui/                     # PhraseListScreen, PhraseFormScreen, PhraseDetailSheet (phân tích lỗi)
│   │
│   ├── android_tools/              # [Phân hệ 4] Tiện ích Android OS (act-14 đến act-17)
│   │   └── ui/                     # AndroidFeaturesScreen (Demo OCR, HomeScreen Widget, Notification)
│   │
│   └── home/                       # Khung điều hướng trung tâm
│       └── main_screen.dart        # Modern NavigationBar 4 tab chuyển đổi mượt mà
│
├── app.dart                        # Cấu hình MultiProvider, MaterialApp, Theme và chuyển đổi Auth/Main
└── main.dart                       # Entry point ứng dụng, khởi tạo TokenStore và các Service
```

---

## 📋 3. Bảng đối chiếu Use Case & API Endpoints

Dự án tuân thủ nghiêm ngặt 20 sơ đồ Use Case / Activity / Sequence trong thư mục `TaiLieuThietKe/` và đặc tả trong `api-reference.html`:

| Nhóm chức năng | Mã Use Case | Endpoint REST | Mô tả nghiệp vụ |
|---|---|---|---|
| **Tài khoản** | `act-01` / `seq-01` | `POST /api/auth/register` | Đăng ký tài khoản (bắt lỗi 400 validation, 409 trùng lặp) |
| | `act-02` / `seq-02` | `POST /api/auth/login` | Đăng nhập nhận cặp Access Token (15p) + Refresh Token |
| | `act-03` / `seq-03` | `POST /api/auth/logout` | Đăng xuất, thu hồi refresh token khỏi hệ thống |
| | `act-04` / `seq-04` | `POST /api/auth/refresh` | **Refresh Token Rotation**: Xóa token cũ, cấp cặp token mới |
| **Từ vựng** | `act-05` / `seq-05` | `GET /api/words` | Lấy danh sách từ của tôi (kèm lọc tab Ôn tập trên client) |
| | — | `GET /api/words/due-count` | Đếm nhanh số từ đã đến hạn ôn tập (`nextReview <= now`) |
| | `act-06` / `seq-06` | `POST /api/words` | Thêm từ mới (1NF đa nghĩa: nghĩa, phiên âm, từ loại, ví dụ) |
| | `act-07` / `seq-07` | `PUT /api/words/{id}` | Cập nhật từ và danh sách nghĩa (chống IDOR 403, trùng 409) |
| | `act-08` / `seq-08` | `DELETE /api/words/{id}` | Xóa từ khỏi sổ (cascade toàn bộ nghĩa) |
| | `act-09` / `seq-09` | `GET /api/words/generate` | AI sinh nghĩa **Cache-First**: tra `word_cache` trước khi gọi AI |
| | `act-19` / `seq-19` | `POST /api/words/review` | **Xác nhận ôn tập (SRS):** Giãn cách 1, 2, 4, 7, 15, 30 ngày |
| | `act-20` / `seq-20` | `POST /api/words/generate-topic` | Bước 1: AI sinh 10 từ theo chủ đề (loại trừ từ đã có trong sổ) |
| | `act-20` / `seq-20` | `POST /api/words/generate-topic/confirm`| Bước 2: Lưu các từ đã chọn vào sổ từ trong một giao dịch |
| **Đoạn văn** | `act-10` / `seq-10` | `GET /api/phrases` | Lấy danh sách bài viết đã chấm kèm điểm số |
| | `act-11` / `seq-11` | `POST /api/phrases` | Gửi bài viết (10–5000 ký tự), AI chấm điểm và lưu kết quả |
| | `act-12` / `seq-12` | — *(Internal)* | AI chấm điểm: tính score 0–10, correctedText và grammar_errors |
| | `act-13` / `seq-13` | `DELETE /api/phrases/{id}`| Xóa đoạn văn (cascade lỗi ngữ pháp) |
| **Android OS** | `act-14` / `seq-14` | Client Service | Thông báo nhắc nhở ôn tập định kỳ hàng ngày |
| | `act-15` / `seq-15` | Client Service | Widget màn hình chính cập nhật số từ đến hạn |
| | `act-16` / `seq-16` | Android Intent | Bôi đen văn bản ở ứng dụng khác và chọn thêm vào LEnglish |
| | `act-17` / `seq-17` | ML Kit OCR | Quét ảnh/camera trích xuất chữ đưa vào ô chấm bài |

---

## ⚙️ 4. Quy ước kỹ thuật quan trọng cho Developer & AI Agent

Khi tiếp tục mở rộng hoặc refactor codebase, **bắt buộc tuân thủ các nguyên tắc sau**:

1. **Chuẩn hóa 1NF cho thuộc tính đa trị (`WordValue`):**
   * Không lưu dạng JSON chuỗi hay gộp dòng. Bảng `word_values` có 5 trường độc lập: `vietnamese` (bắt buộc), `example`, `exampleTranslation`, `pronunciation`, `partOfSpeech`.
   * Enum `PartOfSpeech` (8 từ loại) trong Dart đã ánh xạ tương thích cả chữ HOA Jackson gửi (`NOUN`) lẫn chữ thường MySQL lưu (`noun`).
2. **Xác thực tự động (Self-healing Token Rotation):**
   * Mọi request (trừ nhóm `/api/auth/*`) đều đi qua [`AuthInterceptor`](file:///c:/Users/dell/Documents/PTUD/l_english/lib/core/network/auth_interceptor.dart), tự động gắn `Authorization: Bearer <accessToken>`.
   * Khi gặp lỗi `401`, interceptor sử dụng cơ chế *single-flight lock* để gọi `POST /api/auth/refresh` duy nhất 1 lần, cập nhật token mới và retry request hỏng mà không gây xung đột xoay vòng token.
3. **Mã trạng thái HTTP thống nhất:**
   * `400`: Lỗi dữ liệu đầu vào (từ không phải tiếng Anh, đoạn văn < 10 ký tự, chủ đề vô nghĩa).
   * `401`: Phiên đăng nhập hết hạn hoặc token không hợp lệ.
   * `403`: Lỗi truy cập tài nguyên của người khác (chống IDOR).
   * `409`: Vi phạm ràng buộc duy nhất (trùng username hoặc trùng từ `(user_id, english)`).
   * `502`: Dịch vụ AI bên ngoài bị lỗi hoặc timeout.
4. **Chế độ phát triển linh hoạt (Dual Mode):**
   * **Chế độ Mock (Mặc định):** [`MockWordApi`](file:///c:/Users/dell/Documents/PTUD/l_english/lib/features/words/data/mock_word_api.dart), [`MockAuthApi`](file:///c:/Users/dell/Documents/PTUD/l_english/lib/features/auth/data/mock_auth_api.dart), [`MockPhraseApi`](file:///c:/Users/dell/Documents/PTUD/l_english/lib/features/phrases/data/mock_phrase_api.dart) chạy hoàn toàn trong bộ nhớ với độ trễ giả lập và luật nghiệp vụ thật 100%, cho phép dev và kiểm thử offline ngay lập tức.
   * **Chế độ Remote:** Kết nối trực tiếp tới Spring Boot backend qua cấu hình `--dart-define`.

---

## 🚀 5. Hướng dẫn chạy & Kiểm thử

### 5.1. Khởi chạy ứng dụng

* **Chạy với Mock in-memory (mặc định — sẵn tài khoản mẫu `user1` / `password123`):**
  ```bash
  flutter run
  ```

* **Chạy kết nối Backend Spring Boot thật:**
  * Với Backend qua Cloudflare Tunnel (chạy trên Chrome):
    ```bash
    flutter run -d chrome --no-pub --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://flooring-partners-surely-developer.trycloudflare.com
    ```
  * Với Backend qua Cloudflare Tunnel (chạy trên Máy ảo Android):
    ```bash
    flutter run -d android --no-pub --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://flooring-partners-surely-developer.trycloudflare.com
    ```
  * Với Android Emulator nội bộ (`10.0.2.2` trỏ về localhost máy chủ):
    ```bash
    flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://10.0.2.2:8080
    ```
  * Hoặc nhấp đúp chạy nhanh file kịch bản có sẵn: [`run_chrome.bat`](file:///c:/Users/dell/Documents/PTUD/l_english/run_chrome.bat) hoặc [`run_emulator.bat`](file:///c:/Users/dell/Documents/PTUD/l_english/run_emulator.bat).

### 5.2. Kiểm tra mã nguồn & Chạy kiểm thử tự động

Dự án duy trì tiêu chuẩn kiểm thử khắt khe:
```powershell
# 1. Phân tích cú pháp và quy chuẩn (yêu cầu: 0 lỗi, 0 cảnh báo)
flutter analyze

# 2. Chạy toàn bộ 71 bài kiểm thử tự động (Unit test, Model test, Controller test, Widget test)
$env:NO_PROXY="localhost,127.0.0.1"; flutter test --no-pub
```

---

## 📚 6. Tài liệu thiết kế tham chiếu

Tất cả sơ đồ mô hình hóa và tài liệu chi tiết được lưu trữ trực tiếp trong dự án:
* **`TaiLieuThietKe/README.md`**: Thuyết minh tổng thể hệ thống, phân tích rà soát luồng theo chuẩn quốc tế.
* **`TaiLieuThietKe/class-diagram.puml`**: Sơ đồ lớp JPA Entities (PlantUML).
* **`TaiLieuThietKe/use-case-diagram.puml`**: Sơ đồ Use Case tổng quát.
* **`TaiLieuThietKe/activity/`**: 20 sơ đồ Activity (`act-01` đến `act-20`).
* **`TaiLieuThietKe/sequence/`**: 20 sơ đồ Sequence tương ứng (`seq-01` đến `seq-20`).
* **`api-reference.html`**: Cẩm nang tra cứu 16 endpoint REST API (JSON Schema, DTOs, HTTP Status Codes).
