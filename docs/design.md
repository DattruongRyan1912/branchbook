# BranchBook — Design Doc (v1)

> Bài B1 của tuần 1. Trả lời từng mục ngắn gọn, có số liệu khi được. Xoá các dòng gợi ý (bắt đầu bằng `>`) khi viết xong.

## 1. Bối cảnh & mục tiêu
> Hệ thống giải quyết vấn đề gì, cho ai? Phạm vi MVP gồm gì, KHÔNG gồm gì?

## 2. Yêu cầu
### Chức năng
> Liệt kê các hành động chính của hội viên và quản lý chi nhánh.

### Phi chức năng
> Số chi nhánh/phòng, lưu lượng giờ cao điểm, mục tiêu p95 cho API đặt lịch, mức độ nhất quán cần có (được phép đặt trùng không?), múi giờ.

## 3. Mô hình dữ liệu
> Bảng nào, cột chính nào, quan hệ ra sao, ràng buộc (FK, unique, check) và index nào phục vụ query nào.

## 4. API
> Bảng: method, path, mô tả, mã lỗi có thể trả.

## 5. Điểm tranh chấp dữ liệu
> Chuyện gì xảy ra khi 2 người cùng đặt 1 slot? Bạn chọn cách nào (lock, unique, cả hai…) và vì sao?

## 6. Lỗi & trường hợp đặc biệt
> Retry từ client, membership hết hạn giữa chừng, đặt slot đã qua, huỷ sát giờ, ranh giới 21:00…

## 7. Vận hành
> Log, health check, những gì sẽ làm ở các tuần sau (queue, broker).

## 8. Đánh đổi & phương án đã loại
> Ít nhất 2 quyết định, mỗi quyết định nêu phương án khác và lý do không chọn.
