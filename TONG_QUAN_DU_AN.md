# TỔNG QUAN DỰ ÁN — LEnglish

> **Ngày kiểm tra:** 28/10/2026  
> **Thư mục:** `C:\Users\dell\Documents\PTUD\l_english`  
> **Loại dự án:** Flutter app (client), backend Spring Boot nằm ngoài repo  
> **Nhánh hiện tại:** `develop` — working tree sạch, HEAD `20e7634`

---

## 1. Dự án là gì?

**LEnglish** là ứng dụng học từ vựng tiếng Anh, kết hợp:

- **SRS (Spaced Repetition):** giãn cách ôn tập `1 → 2 → 4 → 7 → 15 → 30` ngày.
- **AI sinh nghĩa từ:** trả CEFR (A1–C2), IPA, từ loại, nghĩa tiếng Việt, ví dụ; cơ chế **cache-first**.
- **AI sinh từ theo chủ đề:** nhập chủ đề → sinh 10 từ mới, loại trừ từ đã có.
- **AI chấm đoạn văn:** điểm 0–10, câu sửa chuẩn, danh sách lỗi ngữ pháp + giải thích tiếng Việt.
- **Tích hợp Android:** widget màn hình chính, bôi đen văn bản từ app khác, OCR ảnh bằng ML Kit, nhắc ôn tập.
- **OTA:** Shorebird CodePush (App ID `95861344-11a7-47da-a26c-7a504b060900`).

Repo **chỉ chứa Flutter client**; backend REST + MySQL 8 + JWT được mô tả trong `TaiLieuThietKe/` và `api-reference.html`, không có mã nguồn server trong đây.

---

## 2. Công nghệ & phiên bản

| Thành phần | Giá trị |
|---|---|
| Framework | Flutter (stable), Dart SDK `^3.13.4` |
| App version | `1.0.0+1` |
| State management | `provider` 6.1.5 |
| HTTP | `dio` 5.11.1 |
| OCR | `google_mlkit_text_recognition` 0.17.1 |
| Ảnh | `image_picker` 1.2.4 |
| Lint | `flutter_lints` 6.0.0 |
| Android | Kotlin, Java 17, `applicationId com.lenglish.l_english`, multiDex bật |
| OTA | Shorebird CodePush |
| Backend tương thích | Spring Boot REST, JWT Bearer + refresh token rotation, MySQL 8 |

---

## 3. Kiến trúc

**Feature-First + Layered Architecture**, mỗi feature chia `data / state / ui`:

```text
lib/
├── core/
│   ├── auth/token_store.dart          # TokenPair + TokenStore + InMemoryTokenStore
│   ├── config/app_config.dart         # Base URL, normalize URL, test kết nối, mock flag
│   ├── network/
│   │   ├── api_client.dart            # Dio client
│   │   ├── api_exception.dart         # Chuẩn hóa lỗi HTTP
│   │   ├── auth_interceptor.dart      # Bearer JWT + refresh token single-flight
│   │   └── ssl_helper*.dart           # Bypass cert có điều kiện
│   ├── services/ocr/                  # OCR mobile + stub web/desktop
│   ├── services/widget/               # MethodChannel widget + process text
│   ├── state/safe_change_notifier.dart
│   ├── theme/app_theme.dart           # Material 3, Blue/Emerald/Violet
│   ├── ui/status_views.dart           # Loading / Error / Empty
│   └── utils/date_format.dart
├── features/
│   ├── auth/                          # Đăng ký, đăng nhập, đăng xuất, profile
│   ├── words/                         # CRUD từ, SRS, quiz, topic, cấu hình kết nối
│   ├── phrases/                       # CRUD đoạn văn, chấm điểm, chi tiết lỗi
│   ├── android_tools/                 # Màn hình tiện ích Android
│   └── home/                          # NavigationBar 4 tab + deep link/intent
├── app.dart                           # MultiProvider + MaterialApp + Auth/Main switch
└── main.dart                          # Chọn Mock/Remote API, khởi tạo Dio
```

**Quy mô mã nguồn (đo tại thời điểm kiểm tra):**

- `lib/`: **53 file Dart, ~7.908 dòng**
- `test/`: **12 file, ~1.271 dòng**

---

## 4. Chức năng đã triển khai

### 4.1. Tài khoản (`act-01..04`)

- Đăng ký / đăng nhập / đăng xuất / refresh token.
- `AuthInterceptor` gắn Bearer token, gặp `401` thì refresh **một lần** (single-flight) rồi retry.
- Màn hình đăng nhập có dialog **cấu hình Base URL**, kiểm tra kết nối, chuẩn hóa URL (tự thêm `http/https`, bỏ `/api`, bỏ `/` cuối).
- `ProfileScreen` hiển thị phiên hiện tại.
- **Lưu ý:** token chỉ nằm trong RAM (`InMemoryTokenStore`), khởi động lại app là mất phiên.

### 4.2. Từ vựng & SRS (`act-05..09, 15, 16, 19, 20`)

- Danh sách từ 2 tab: **Tất cả** / **Ôn tập (dueCount)**; tìm kiếm theo từ hoặc nghĩa tiếng Việt.
- Thêm / sửa / xóa từ; model 1NF `WordValue` gồm `vietnamese`, `example`, `exampleTranslation`, `pronunciation`, `partOfSpeech`.
- Enum `Level` (A1–C2) và `PartOfSpeech` (8 loại), ánh xạ được cả `NOUN` và `noun`.
- **Sinh nghĩa AI** (cache-first), **sinh 10 từ theo chủ đề** rồi xác nhận lưu.
- **Review Quiz:** trắc nghiệm 4 đáp án, tự tạo đáp án nhiễu, hiện IPA/CEFR/ví dụ, phản hồi đúng-sai, tự gọi `/api/words/review` cập nhật SRS.
- Sau khi ôn tập, đồng bộ lại widget Android.
- Mock API mô phỏng đủ mã lỗi `400 / 403 / 409 / 502`, cache và thuật toán SRS.

### 4.3. Đoạn văn & chấm AI (`act-10..13, 17`)

- Danh sách bài đã chấm kèm điểm, số lỗi.
- Form nhập **10–5000 ký tự**, đếm ký tự, validate hai lớp (controller + mock API).
- OCR từ ảnh/camera (ML Kit) đổ văn bản vào form.
- Bottom sheet chi tiết: điểm, câu gốc, câu sửa, từng lỗi + giải thích.
- Xóa đoạn văn (cascade lỗi ngữ pháp phía backend).

### 4.4. Tích hợp Android (`act-14..17`)

| Tính năng | Trạng thái thực tế |
|---|---|
| **ACT-15 Widget** | ✅ Có native `DueWordsWidgetProvider.kt`, layout widget, gọi trực tiếp `GET /api/words/due-count`, cache SharedPreferences, nút refresh, chạm mở `lenglish://review` → tab Ôn tập |
| **ACT-16 Bôi đen/chia sẻ** | ✅ `ACTION_PROCESS_TEXT` + `ACTION_SEND`, MethodChannel `onProcessText`, mở `WordFormScreen` với từ điền sẵn |
| **ACT-17 OCR** | ✅ ML Kit trên mobile; stub trên web/desktop |
| **ACT-14 Thông báo** | ⚠️ **Chỉ là UI mô phỏng** trong `AndroidFeaturesScreen`; chưa có WorkManager/NotificationManager native |

### 4.5. Điều hướng

`MainScreen` dùng `NavigationBar` 4 tab: **Từ vựng / Chấm bài / Tiện ích / Tài khoản**, giữ state bằng `IndexedStack`, nhận intent widget và process text.

---

## 5. API client đang gọi (16 endpoint)

**Auth (4):** `POST /api/auth/register`, `/login`, `/logout`, `/refresh`

**Words (9):**

- `GET /api/words`
- `GET /api/words/due-count`
- `POST /api/words`
- `PUT /api/words/{id}`
- `DELETE /api/words/{id}`
- `GET /api/words/generate`
- `POST /api/words/review`
- `POST /api/words/generate-topic`
- `POST /api/words/generate-topic/confirm`

**Phrases (3):** `GET /api/phrases`, `POST /api/phrases`, `DELETE /api/phrases/{id}`

**Quy ước lỗi:** `400` dữ liệu sai, `401` hết phiên, `403` IDOR, `409` trùng dữ liệu, `502` AI lỗi/timeout.

---

## 6. Cấu hình môi trường

Chọn Mock/Remote bằng `--dart-define`:

```powershell
# Mock in-memory (tự đăng nhập user1)
flutter run --dart-define=USE_MOCK_API=true

# Backend thật
flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://<host>
```

- `USE_MOCK_API` mặc định **`false`** (dùng backend thật).
- Base URL mặc định trong code: `https://kristal-nondichotomous-conclusionally.ngrok-free.dev`.
- Timeout: connect 10s, receive 30s.
- Có thể đổi Base URL lúc chạy từ màn hình đăng nhập hoặc `ConnectionSettingsScreen`; **không lưu qua lần khởi động sau**.
- Script tiện dụng: `run_app.bat`, `run_chrome.bat`, `run_emulator.bat`, `build_apk.bat`.

---

## 7. Build & kiểm thử

| Hạng mục | Kết quả kiểm tra |
|---|---|
| `flutter analyze --no-pub` | ✅ **No issues found** (37.3s) |
| `flutter test --no-pub` | ✅ **90 passed, 1 skipped** (~9s) |
| Test bị skip | `app_config_test.dart` — test kết nối Cloudflare tunnel thật, lý do "tunnel tạm thời có thể hết hạn" |
| APK release có sẵn | `build/app/outputs/flutter-apk/app-release.apk` — **82.7 MB** (27/10/2026) |
| CI/CD | ❌ Không có workflow `.github/` |

Lệnh build:

```powershell
flutter build apk --debug
flutter build apk --release
shorebird release android --artifact apk --flutter-version 3.47.5 --target-platform android-arm64
shorebird patch --platforms=android --release-version=1.0.0+1
```

---

## 8. Tài liệu thiết kế có sẵn

Thư mục `TaiLieuThietKe/`:

- `README.md` — thuyết minh hệ thống, 8 bảng DB, quan hệ, luồng nghiệp vụ.
- `class-diagram.puml`, `use-case-diagram.puml`, `erd-diagram.puml`, `package-diagram.puml`, `deployment-diagram.puml`.
- `activity/` — 20 sơ đồ `act-01..act-20` (`.puml/.png/.svg`).
- `sequence/` — 20 sơ đồ `seq-01..seq-20`.
- Ảnh render PNG/SVG cho từng sơ đồ.
- `slides.html` — bộ slide thuyết trình.
- `api-reference.html` — đặc tả REST API, DTO, JSON schema, mã lỗi.

---

## 9. Git & trạng thái repo

- Remote: `https://github.com/Khanhth2022/l_english.git`
- Tổng commit: **17**
- Nhánh:
  - `develop` — nhánh chính đang dùng, sạch, mới nhất.
  - `feature/words` — **ahead 1** so với remote.
  - `feature/auth`, `feature/phrases`, `feature/android` — đứng ở commit "Tao du an".
  - `main` — commit khởi tạo.
- Không có file thay đổi chưa commit tại thời điểm kiểm tra; riêng `TONG_QUAN_DU_AN.md` là file mới được tạo bởi lần tổng quan này (chưa commit).

---

## 10. Điểm cần lưu ý / rủi ro

1. **Token không được lưu bền:** `InMemoryTokenStore` chỉ giữ RAM → tắt app phải đăng nhập lại. Chưa có `flutter_secure_storage`.
2. **ACT-14 chưa thật:** chỉ có toggle + chọn giờ trên UI, chưa có native notification/WorkManager.
3. **Base URL đã thống nhất:** `app_config.dart`, widget fallback, `README.md`, `run_chrome.bat`, `run_emulator.bat` cùng dùng `https://kristal-nondichotomous-conclusionally.ngrok-free.dev` (tunnel ngrok tạm thời có thể hết hạn).
4. **README lệch code:** README ghi Mock là mặc định, nhưng `USE_MOCK_API` mặc định `false`.
5. **Release ký bằng debug keystore** (`signingConfig = debug`) — không phù hợp phát hành store.
6. **`usesCleartextTraffic="true"`** — cho phép HTTP không mã hóa.
7. **Widget lưu access token trong SharedPreferences** dạng thường và tự gọi API native — cần cân nhắc bảo mật.
8. **Chỉ Android được kiểm chứng:** có scaffold iOS/Linux/macOS/Windows/web nhưng OCR/widget là mobile/Android-specific.
9. **Không có CI**, không có kiểm thử tích hợp backend thật (chỉ mock + 1 test mạng bị skip).
10. `pubspec.yaml` vẫn để `description: "A new Flutter project."`.
11. `TaiLieuThietKe/` **đã được track** (139 file) dù `.gitignore` có ghi chú "giữ ngoài git"; chỉ `.widget_preview/` là thực sự bị ignore.

---

## 11. Tóm tắt một dòng

**LEnglish là Flutter client hoàn chỉnh cho học từ vựng + SRS + AI, kiến trúc feature-first, 53 file/~7.9k dòng, analyze sạch, 90 test pass, tích hợp widget/OCR/process-text Android thật, còn thiếu lưu token bền, notification thật, CI và cấu hình release production.**
