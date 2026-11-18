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

**Rủi ro lịch sử Git:** commit `5e1afdd` chứa các phép gán literal cho
`partnerCode`, `accessKey` và `secretKey` trong
`lib/services/momo_payment_service.dart`; mẫu phép gán vẫn có trong bản của
file ở `HEAD`. File đã được xóa trong working tree hiện tại nhưng vẫn có trong
lịch sử Git. Chủ sở hữu nên thu hồi/rotate
mọi credential MoMo liên quan. VNPay sử dụng credential Sandbox mới và chỉ lưu
qua Firebase Secret Manager. Không dùng việc xóa file hiện tại như bằng chứng
credential cũ đã an toàn; lịch sử Git chưa được viết lại.
