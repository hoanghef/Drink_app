# Báo cáo lỗ hổng

Không đăng công khai token, credential, dữ liệu người dùng, hướng dẫn khai thác
chi tiết hoặc lỗ hổng chưa được xử lý trong GitHub Issue/Discussion.

Repository hiện **chưa có kênh liên hệ bảo mật hoặc địa chỉ email được cấu hình
trong source**. Nếu trang **Security → Report a vulnerability** của repository
được chủ repo bật, hãy dùng kênh báo cáo riêng đó. Nếu chưa bật, cần chủ repo
bổ sung một kênh liên hệ riêng trước khi nhận báo cáo nhạy cảm. Không giả định
một email cá nhân hay địa chỉ của công ty là kênh bảo mật của dự án.

Khi có kênh riêng, báo cáo nên gồm phiên bản/commit, ảnh hưởng, cách tái hiện
an toàn bằng Emulator hoặc test doubles và đề xuất khắc phục. Không gửi
service-account, secret VNPay hay dữ liệu thật trong báo cáo.

**Lịch sử Git:** Toàn bộ lịch sử Git reachable từ `main` và `origin/main`
đã được kiểm tra: commit `5e1afdd` không tồn tại, tệp
`lib/services/momo_payment_service.dart` chưa từng được commit vào lịch sử được theo dõi,
và không có literal credential MoMo nào trong các commit reachable. Tích hợp thanh toán
trong source hiện tại chỉ sử dụng VNPay Sandbox và secret chỉ được cấu hình qua
Firebase Secret Manager/biến môi trường backend, không lưu trong client.
