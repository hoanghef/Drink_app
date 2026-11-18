# Đóng góp

1. Tạo nhánh riêng từ bản mới nhất và mô tả thay đổi trong pull request. Kiểm
   tra `git status` trước khi sửa; không đưa dữ liệu Firebase/VNPay thật, token,
   service account hoặc signing key vào commit. `android/app/google-services.json`
   là cấu hình **client** hiện có, không dùng nó thay cho private credential.
2. Giữ logic xác thực giá, tổng tiền, quyền Admin và `paymentStatus` ở backend.
   Nếu đổi schema order, cập nhật đồng thời Flutter, Functions, rules, test và
   `docs/ARCHITECTURE.md`. Nếu đổi bảng giá size, cập nhật
   `functions/size_pricing.json` và kiểm tra cả app/backend.
3. Dùng `dart format` cho Dart. Trước khi gửi PR, từ thư mục gốc chạy:

   ```sh
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test
   git diff --check
   ```

4. Chạy Node unit tests và Firestore/Storage Emulator theo [TESTING.md](TESTING.md).
   Test VNPay phải dùng phản hồi giả; không chạy giao dịch thật trong CI. Thêm
   test cho hành vi mới, nhất là quyền, retry và thay đổi trạng thái thanh toán.
5. Ghi cách kiểm tra, giới hạn chưa xác minh và ảnh chụp thật nếu UI thay đổi.
   Không thêm badge CI trước khi workflow chạy thành công trên repository.

CI trong `.github/workflows/ci.yml` chỉ kiểm tra; không deploy. Việc triển khai
Firebase, cấp Admin claim hoặc thử VNPay Sandbox phải theo
[SECURITY_SETUP.md](SECURITY_SETUP.md) trên project development và được người
quản lý project thực hiện.
