# Drink App — đặt đồ uống bằng Flutter và Firebase

Dự án portfolio Flutter Intern: ứng dụng đặt đồ uống có giao diện khách hàng và
quản trị viên. Flutter xử lý giao diện và state với Provider; Firebase Auth,
Firestore, Storage và Cloud Functions phục vụ đăng nhập, menu, đơn hàng và ảnh.
Backend tính lại giá theo size trước khi tạo đơn. Mã nguồn và bộ kiểm thử cục bộ (Flutter unit/widget tests, Node unit tests, Emulator rules) cho đặt hàng COD và tích hợp **VNPay Sandbox** đã hoàn thành; tuy nhiên, **Cloud Functions, luồng đặt hàng COD thực tế và VNPay Sandbox chưa được chứng minh hoạt động trên Firebase development hoặc tài khoản Sandbox thật** trong repository này.

## 📱 Screenshots

> [!NOTE]
> Chưa có ảnh chụp màn hình được lưu trong repo. Chủ dự án có thể bổ sung ảnh chụp thật của các màn User, checkout và Admin vào thư mục `docs/screenshots/` rồi liên kết ở đây. Không dùng ảnh giả. Các ảnh sản phẩm trong `assets/images/` là asset mẫu giao diện, không phải ảnh chụp ứng dụng. README không dùng CI badge hoặc demo link chưa được xác minh trực tiếp trên GitHub/Production.

| Trang chủ (Menu) | Chi tiết món & Size | Giỏ hàng & Checkout (COD / VNPay) | Lịch sử đơn hàng | Quản trị viên (Admin) |
|:---:|:---:|:---:|:---:|:---:|
| *(Thêm `home.png`)* | *(Thêm `detail.png`)* | *(Thêm `checkout.png`)* | *(Thêm `orders.png`)* | *(Thêm `admin.png`)* |

## Chức năng có trong source

| Khách hàng | Quản trị viên |
| --- | --- |
| Đăng ký, đăng nhập, đặt lại mật khẩu qua email và đổi mật khẩu | Truy cập bằng Firebase Auth custom claim `admin: true` |
| Xem, tìm kiếm, lọc đồ uống; chọn size S/M/L | Tạo, sửa, sắp xếp, ẩn danh mục bằng key ổn định |
| Giỏ hàng trong bộ nhớ; món yêu thích lưu Firestore theo UID | Thêm, sửa, ẩn/lưu trữ sản phẩm; upload JPEG dưới 5 MB lên Storage |
| Địa chỉ lưu trên thiết bị theo UID; chọn địa chỉ mặc định hoặc nhận tại quán | Xem đơn, chuyển trạng thái qua Callable; ghi nhận COD có audit |
| Đặt COD; mở URL VNPay Sandbox khi đã cấu hình; xem lịch sử và trạng thái thanh toán | Xem tiền đã thu riêng với giá trị đơn; yêu cầu backend đối soát VNPay đang chờ khi đã bật QUERYDR |

Admin không tự cấp quyền trong app. Firestore rules chặn client tạo/sửa order;
Storage chỉ cho Admin upload ảnh. Chi tiết luồng và ranh giới quyền nằm trong
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Stack và cấu trúc

- Flutter/Dart, Provider; `lib/screens`, `lib/providers`, `lib/models`,
  `lib/services` và `lib/widgets`.
- Firebase Authentication, Cloud Firestore, Cloud Storage và Callable/HTTP
  Cloud Functions (Node 22, region `asia-southeast1`).
- Shared Preferences lưu địa chỉ theo UID trên thiết bị; giỏ hàng chỉ nằm trong
  bộ nhớ. Favorites được tải lại theo UID, xóa state khi đổi tài khoản/đăng
  xuất và chỉ đổi UI sau khi ghi Firestore thành công.
  `functions/size_pricing.json` là bảng phụ giá size dùng chung cho app và
  backend.
- Firestore/Storage rules và test Emulator; GitHub Actions kiểm tra Flutter,
  Functions và rules. Workflow chưa được chạy trên GitHub trong checkout này.

## Chạy ứng dụng

1. Cài Flutter 3.38.4 (Dart 3.10.3) và Android SDK; kiểm tra thiết bị bằng
   `flutter doctor` và `flutter devices`.
2. Chọn một Firebase **development** project, bật Email/Password Auth,
   Firestore, Storage và Functions. Android hiện dùng
   `android/app/google-services.json` của một project cụ thể. Khi dùng project
   khác, thay bằng client config Android của bạn với package ID tương ứng.
   Đây là **Firebase client config**, không phải service-account/private key.
   iOS chưa có `GoogleService-Info.plist`; các nền tảng khác chưa có cấu hình
   Firebase được xác minh.
3. Cài package và chạy trên Android:

   ```sh
   flutter pub get
   flutter run -d <android-device-id>
   ```

4. Để **đặt hàng**, cần triển khai Functions và rules lên development project
   theo [SECURITY_SETUP.md](SECURITY_SETUP.md). Chạy
   `npm ci --prefix functions` để cài Admin SDK. Tạo tài khoản thường, sau đó
   cấp Admin claim từ máy quản trị tin cậy bằng
   `node functions/grant_admin.js <uid> grant` với
   `GOOGLE_CLOUD_PROJECT=<project-id>` và Application Default Credentials phù
   hợp. Đăng xuất/đăng nhập lại để làm mới token. Tạo danh mục trước, rồi tạo
   sản phẩm trong Admin UI, hoặc dùng lệnh seed catalog dưới đây. Không có seed
   tự động khi mở app.

### Seed catalog mẫu

Từ `functions/`, sau `npm ci`, dùng project development hoặc Firestore Emulator:

```sh
npm run seed:catalog -- --project <development-project-id> --dry-run
npm run seed:catalog -- --project <development-project-id> --apply
```

`--dry-run` chỉ đọc và liệt kê thao tác; `--apply` cần Application Default
Credentials có quyền ghi hoặc `FIRESTORE_EMULATOR_HOST`. Chọn đúng project trước
khi apply. Lệnh chỉ tạo category/product còn thiếu theo ID mẫu, không ghi đè menu
đã chỉnh. Nếu menu hiện có dùng ID sản phẩm khác, lệnh đầy đủ có thể tạo thêm
sản phẩm mẫu cùng tên; cần xem danh sách `products/*` trong dry-run trước khi apply.
Menu User đọc được danh mục cũ có ID khác key nếu `name` hợp lệ, đang hoạt
động và không trùng key. Không cần chạy seed để xem menu. Để **chuẩn hóa danh
mục cho thao tác ghi catalog của Admin** mà giữ nguyên menu sản phẩm, dùng:

```sh
npm run seed:catalog -- --project <development-project-id> --categories-only --dry-run
npm run seed:catalog -- --project <development-project-id> --categories-only --apply
```

category seed cũ có document ID khác key được sao chép sang ID chuẩn và document
cũ được ẩn, không xóa. Xem [SECURITY_SETUP.md](SECURITY_SETUP.md) để kiểm tra
kết quả và xử lý trường hợp category đang ẩn.

### Khi trang chủ trống hoặc không vào được Admin

- App không tự thêm sản phẩm. Nếu trang chủ báo chưa có danh mục/sản phẩm, kiểm
  tra đúng Firebase project trong `android/app/google-services.json`. Danh mục
  phải đang hoạt động và `products.category` phải tham chiếu `name` của nó.
  Document ID cũ vẫn đọc được để hiện menu, nhưng cần chuẩn hóa ID trước khi
  Admin tạo/sửa sản phẩm theo Firestore rules hiện tại.
- Đăng ký tài khoản chỉ tạo User. Để vào Admin, cấp custom claim bằng công cụ
  quản trị tin cậy theo [SECURITY_SETUP.md](SECURITY_SETUP.md), trên **cùng**
  Firebase project với app. Sau đó đăng xuất/đăng nhập lại hoặc mở lại app để
  làm mới ID token. Sửa `users.role` không cấp quyền Admin.
- Lỗi tải dữ liệu hoặc xác minh quyền nay có thông báo và nút thử lại; nếu vẫn
  xảy ra, kiểm tra kết nối, rules đã deploy và project ID. Không đưa credential
  quản trị vào app để khắc phục.

### Android build

`flutter build apk --debug` dùng debug signing. Để build release, chủ repo tự
tạo keystore và sao chép `android/key.properties.example` thành
`android/key.properties` (file local bị ignore), điền đường dẫn và các thông số
signing. Sau đó chạy `flutter build apk --release` hoặc
`flutter build appbundle --release`. Build release thiếu cấu hình sẽ thất bại;
không dùng debug key làm fallback. Gradle wrapper scripts/JAR cần có trong Git
để build trên máy sạch.

Lệnh cấu hình/deploy chỉ là hướng dẫn; repository này chưa chứng minh đã triển
khai Functions/rules hoặc cấu hình VNPay trên Firebase thật.

## Luồng đặt hàng

- **COD:** `placeOrder` kiểm tra Auth, sản phẩm còn bán, size, số lượng, địa chỉ
  và tổng tiền rồi tạo order một lần theo `requestId`. Order lưu snapshot tên,
  giá đơn vị, size và số lượng; COD bắt đầu `paymentStatus: unpaid`. Admin chỉ
  ghi nhận đã thu qua `collectCodPayment` với custom claim, thời gian, UID và
  audit.
- **VNPay Sandbox:** lựa chọn chỉ bật khi backend có Secret Manager, IPN URL và
  Return URL. `createVnpayPayment` tạo order `pending` và ký URL thanh toán;
  Flutter mở URL đó trong trình duyệt ngoài. IPN có chữ ký mới xác nhận `paid`;
  QUERYDR chỉ bật sau khi kiểm chứng cấu hình Sandbox và phản hồi có chữ ký.
  Quay lại app, timeout hoặc kết quả đang chờ không
  được coi là đã thanh toán. Chưa có kiểm chứng end-to-end với tài khoản
  Sandbox thật.

## Kiểm thử và tài liệu

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Backend unit tests dùng `node --test`; Firestore/Storage rules dùng Firebase
Emulator và Java 21. Lệnh đầy đủ, CI và dependency audit nằm trong
[TESTING.md](TESTING.md). Hướng dẫn Firebase, Secret Manager và cấp Admin nằm
trong [SECURITY_SETUP.md](SECURITY_SETUP.md). Quy trình đóng góp và báo cáo lỗ
hổng ở [CONTRIBUTING.md](CONTRIBUTING.md) và [SECURITY.md](SECURITY.md).

## Giới hạn đã biết

- **Triển khai live:** Source và test local cho COD, VNPay Sandbox (HMAC-SHA512, IPN, reconcile) và Cloud Functions đã hoàn thành trong repo và vượt qua 100% tests cục bộ (30 Flutter tests, 32 Node tests, 39 Emulator tests, Android debug build thành công). Tuy nhiên, Cloud Functions, quy trình COD và giao dịch VNPay chưa được chứng minh hoạt động trên Firebase development hoặc merchant Sandbox thật.
- **Bảo mật và lịch sử Git:** Credential MoMo cũ (trong commit `5e1afdd` tại `lib/services/momo_payment_service.dart`) đã được chủ sở hữu revoke/vô hiệu hóa. Tuy nhiên, do repository GitHub đã tồn tại trực tuyến, lịch sử Git vẫn còn lưu vết commit cũ và cần được chủ repo xử lý (sử dụng công cụ viết lại lịch sử như `git-filter-repo` để loại bỏ hoàn toàn); việc xóa tệp ở `HEAD` không đồng nghĩa lịch sử Git đã an toàn.
- Địa chỉ không đồng bộ giữa thiết bị. Favorites đã có test cho đổi tài khoản, document rỗng, response tải muộn và lỗi ghi; chưa thử luồng này với nhiều thiết bị hoặc Firebase thật.
- Đơn VNPay `pending` có thể kéo dài khi IPN/query không cho kết quả rõ ràng; cần đối soát thủ công theo `SECURITY_SETUP.md`. Không sửa trạng thái thanh toán trực tiếp từ client.
- Chạy `npm audit --omit=dev` trong `functions/` để xem advisory hiện tại; hướng xử lý và giới hạn dependency nằm trong `TESTING.md`.
- Repo chưa có license và chưa có ảnh chụp ứng dụng thật được commit. Cần chủ repo chọn license và cung cấp ảnh nếu muốn công bố hai mục này.
