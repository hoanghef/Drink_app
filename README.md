# ☕ Coffee Shop App - Flutter & Firebase E-Commerce

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Provider](https://img.shields.io/badge/Provider-State_Management-blue?style=for-the-badge)

Một ứng dụng thương mại điện tử đặt đồ uống trên thiết bị di động được phát triển bằng **Flutter** và **Firebase**. Dự án bao gồm cả 2 phân hệ **Khách hàng (User)** và **Quản trị viên (Admin)** tích hợp trong cùng một codebase, hỗ trợ thanh toán trực tuyến qua ví MoMo và đồng bộ dữ liệu theo thời gian thực.

> 🎓 **Dự án thuộc Đồ án cơ sở - Khoa CNTT, Đại học Phenikaa**

---

## 📸 1. Giao diện ứng dụng (Screenshots)


| Khách hàng (User) | Chi tiết & Giỏ hàng | Quản trị viên (Admin) |
|:---:|:---:|:---:|
| <img width="250" alt="Screenshot_1772878911" src="https://github.com/user-attachments/assets/c9f86bd7-0971-4c94-8c2c-9434cd535fdc" /> | <img width="250" alt="Screenshot_1772878920" src="https://github.com/user-attachments/assets/3035e964-a40e-4076-86ef-c17f388f5294" /> | <img width="250" alt="Screenshot_1772880631" src="https://github.com/user-attachments/assets/605dbbf5-3e44-4048-a233-622a384531af" /> |

---

## ✨ 2. Tính năng nổi bật (Key Features)

### 👤 Phân hệ Khách hàng (User)
- **Xác thực an toàn:** Đăng nhập, Đăng ký, Quên mật khẩu (gửi link qua Email), Đổi mật khẩu.
- **Trải nghiệm mua sắm mượt mà:** Xem danh sách đồ uống, tìm kiếm sản phẩm, tùy chỉnh kích cỡ (S, M, L) thay đổi giá tự động.
- **Quản lý cá nhân:** Thêm món vào danh sách Yêu thích (Favorite), thiết lập Sổ địa chỉ (Address Book) với địa chỉ mặc định.
- **Thanh toán đa dạng:** Hỗ trợ thanh toán Tiền mặt (COD) và tích hợp API Ví điện tử MoMo (Có cơ chế Fallback giả lập khi Sandbox bảo trì).
- **Theo dõi đơn hàng:** Lịch sử đơn hàng đồng bộ Real-time.

### 🛡️ Phân hệ Quản trị viên (Admin)
*(Truy cập bằng tài khoản có role `admin`)*
- **Dashboard Thống kê:** Theo dõi trực quan doanh thu và số lượng đơn hàng.
- **Quản lý Menu:** Thêm, sửa, xóa, ẩn/hiện sản phẩm. Tải ảnh trực tiếp lên Firebase Cloud Storage.
- **Quản lý Đơn hàng Real-time:** Nhận thông báo đơn hàng mới ngay lập tức, cập nhật trạng thái (Chờ xác nhận -> Đang giao -> Hoàn thành) đồng bộ thẳng tới máy khách.

---

## 🛠️ 3. Công nghệ & Kiến trúc (Tech Stack & Architecture)

- **Frontend:** Flutter & Dart.
- **Backend (BaaS):** Firebase Authentication, Cloud Firestore (NoSQL), Firebase Storage.
- **State Management:** `provider` (Quản lý trạng thái giỏ hàng, user session, địa chỉ).
- **External API:** API MoMo Payment Sandbox.
- **Kiến trúc thư mục (Folder Structure):**
  ```text
  lib/
  ├── models/       # Định nghĩa các Data Models (User, Product, Order...)
  ├── providers/    # Quản lý State tập trung (CartProvider, AuthProvider...)
  ├── screens/      # Các màn hình UI (Chia ra thư mục con user/ và admin/)
  ├── services/     # Xử lý Logic ngoại vi (Firebase, MoMoPaymentService)
  ├── widgets/      # Các UI Components tái sử dụng (Buttons, Cards, Dialogs)
  ├── themes.dart   # Cấu hình màu sắc, phông chữ chung
  └── main.dart     # Entry point
