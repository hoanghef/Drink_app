# Kiểm thử và CI

Workflow được cấu hình cho `push` và `pull_request` bằng Flutter 3.38.4,
Node 22 và Java 21; chưa xác minh lần chạy nào trên GitHub.
Không cần Firebase/VNPay credential, không deploy và không gọi VNPay Sandbox.
Test VNPay dùng phản hồi giả được tiêm vào backend và chặn `fetch` mặc định.

## Lệnh chạy cục bộ

Từ thư mục gốc:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

Từ `functions/`, cài dependency đúng lockfile bằng `npm ci`. Để chạy unit
backend không cần Java/Emulator:

```sh
npm ci
node --test test/admin_orders.test.js test/vnpay.test.js test/order_logic.test.js test/place_order.test.js
npm audit --omit=dev
```

Để chạy cả Firestore/Storage rules, từ thư mục gốc với Java 21 trong `PATH`:

```sh
./functions/node_modules/.bin/firebase emulators:exec --project demo-drink-app-p0-test --only auth,firestore,storage "cd functions && npm test"
```

Trên Windows PowerShell, dùng `./functions/node_modules/.bin/firebase.cmd`
và `npm.cmd`. Dự án `demo-...` là project giả của Emulator; các lệnh trên
không truy cập dữ liệu Firebase thật. CI dùng đúng lệnh Emulator này, nên
analyzer hoặc bất kỳ test thất bại sẽ làm job thất bại. Workflow không chạy
`npm audit` như một gate vì còn advisory transitive được ghi bên dưới.

## Dependency audit hiện tại

Chạy `npm audit --omit=dev` trong `functions/` để xem số advisory hiện tại;
kết quả có thể thay đổi khi registry cập nhật. Lần rà soát gần đây ghi nhận
advisory trong các nhánh phụ thuộc sau:

| Package | Nguồn ảnh hưởng |
| --- | --- |
| `firebase-admin` | `@google-cloud/firestore`, `@google-cloud/storage` |
| `@google-cloud/firestore` | `google-gax` |
| `@google-cloud/storage` | `retry-request`, `teeny-request` |
| `google-gax` | `retry-request`, `uuid` |
| `retry-request` | `teeny-request` |
| `teeny-request` | `uuid` |
| `gaxios` | `uuid` |
| `uuid` | Advisory về giới hạn buffer ở một số hàm UUID |

`npm audit fix --dry-run --omit=dev` chưa tìm được thay đổi dependency tương
thích (`changed: 0` trong lượt kiểm tra này). npm đề xuất nâng major
`firebase-admin` cho phần lớn chuỗi này; chưa áp dụng tự động. Rủi ro còn lại là dependency
production vẫn mang các advisory trên; cần kiểm tra tương thích Admin SDK và
Functions, chạy toàn bộ Emulator/test, rồi quyết định nâng cấp trong một PR
riêng. Không dùng `npm audit fix --force` hoặc override `uuid` major mù quáng.

`pubspec.lock` được Git theo dõi. `functions/package-lock.json` hiện có và
không bị ignore nhưng vẫn là file chưa được Git theo dõi trong working tree;
cần đưa vào cùng source backend khi tạo commit sau này. `functions/node_modules`,
build output, log Emulator và file `.env` được ignore.

## Seed catalog và Android build

`npm run seed:catalog -- --project <project-id> --dry-run` chỉ đọc catalog và
liệt kê các thao tác dự kiến. `--apply` dùng Application Default Credentials
hoặc `FIRESTORE_EMULATOR_HOST`, tạo mục còn thiếu và chuyển ID category seed cũ
sang key chuẩn mà không xóa document. Không chạy `--apply` trên dữ liệu thật
trong CI. Node test `seed_catalog.test.js` kiểm tra plan idempotent; Emulator
test kiểm tra product chỉ tham chiếu category đang hoạt động và ID khớp key.

`flutter build apk --debug` kiểm tra Android debug. Release cần
`android/key.properties` local theo `android/key.properties.example` và keystore
của chủ repo; không dùng debug signing làm fallback. Không chạy release build
trong CI khi chưa có signing key.
