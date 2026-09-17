# Reflection - Session 01

### 1. Khó khăn khi cài Docker/DBeaver và cách xử lý
Khi chạy Docker Compose, cổng `5432` bị chiếm do PostgreSQL máy chủ đang chạy sẵn. Tôi xử lý bằng cách dừng service local (`sudo systemctl stop postgresql`) và cấu hình kết nối chuẩn xác trên DBeaver.

### 2. Lý do chọn Data Type cho tiền tệ, thời gian, ID
* **Tiền tệ:** Dùng `NUMERIC(14,2)` nhằm tránh sai số làm tròn số thực (ví dụ: `order_total NUMERIC(14,2)`).
* **Thời gian:** Dùng `TIMESTAMPTZ` nhằm chuẩn hóa múi giờ UTC, tránh lệch giờ giao dịch.
* **ID:** Dùng `VARCHAR` vì mã nghiệp vụ thường chứa tiền tố chữ cái (ví dụ: `CUST-001`).

### 3. Quan hệ 1:N giữa customers và orders
Một khách hàng có thể có nhiều đơn hàng, nhưng mỗi đơn chỉ thuộc về một khách hàng duy nhất qua khóa ngoại `customer_id`.
* *Ví dụ:* Khách hàng `CUST-001` có 2 đơn hàng `ORD-101` và `ORD-102` cùng tham chiếu `CUST-001`.

### 4. Xử lý sửa schema (ALTER vs Tạo lại)
Ưu tiên dùng `ALTER TABLE` qua file migration. Lệnh tạo lại (`DROP & CREATE`) sẽ xóa sạch dữ liệu và gây downtime. Dùng `ALTER TABLE` giúp thêm cột hoặc đổi FK an toàn mà vẫn giữ nguyên dữ liệu.

