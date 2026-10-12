# BranchBook — Design Doc (v1)

> Bài B1 của tuần 1. Trả lời từng mục ngắn gọn, có số liệu khi được. Xoá các dòng gợi ý (bắt đầu bằng `>`) khi viết xong.
>
> Mục 3, 4 (sở hữu dữ liệu), 6, 8, 9, 10 ghi lại từ buổi hỏi–đáp 2026-10-11/12. Phần đánh dấu *(lời giải mẫu)* là chỗ người viết đã xin xem lời giải. Mục còn dòng `>` là chưa trả lời.

## 1. Bối cảnh & mục tiêu
> Hệ thống giải quyết vấn đề gì, cho ai? Phạm vi MVP gồm gì, KHÔNG gồm gì?

## 2. Yêu cầu
### Chức năng
> Liệt kê các hành động chính của hội viên và quản lý chi nhánh.

### Phi chức năng
> Số chi nhánh/phòng, lưu lượng giờ cao điểm, mục tiêu p95 cho API đặt lịch, mức độ nhất quán cần có (được phép đặt trùng không?), múi giờ.

## 3. Kiến trúc service

Microservice ngay từ đầu (không tách dần từ monolith): muốn luyện tách service thật, chấp nhận bản demo đầu tiên lùi về tuần 4.

| Service | Stack | Việc chính |
|---|---|---|
| gateway | Traefik | Định tuyến theo path, rate limit, CORS |
| identity | NestJS + PostgreSQL | Đăng ký, đăng nhập, cấp/làm mới/thu hồi token, công khai public key |
| authz | NestJS + PostgreSQL | Gán vai trò theo chuỗi/chi nhánh |
| booking | Laravel 13 (Octane/Swoole) + MySQL + Redis | Chuỗi, chi nhánh, phòng, slot, đặt/huỷ chống trùng, outbox |
| notification | NestJS + PostgreSQL | Nhận event, gửi email, nhắc lịch, WebSocket |
| storage | NestJS + MinIO | Upload/download file qua presigned URL |
| web | Next.js | Giao diện |

- Hạ tầng dùng chung: 1 MySQL, 1 PostgreSQL (mỗi service có database + user riêng, không truy vấn chéo), 1 Redis (tách theo tiền tố khoá), RabbitMQ, MinIO.

### Event và thông báo
- Event mang đủ dữ liệu mà service phát sở hữu, chỉ mang id với dữ liệu của service khác. Ví dụ `booking.cancelled`: `event_id`, `correlation_id`, `booking_id`, `user_id`, giờ bắt đầu, tên phòng, tên chi nhánh, lý do huỷ.
- Notification giữ bản sao `user_id → email, tên, ngôn ngữ` (chỉ trường cần dùng), nạp toàn bộ một lần rồi nghe `user.updated`; nhận `user.anonymized` thì ẩn danh bản sao. Lúc gửi email không phụ thuộc identity.
- Gộp email theo đợt: mọi event sinh ra từ một thao tác mang chung `correlation_id`; notification gom theo `(user_id, correlation_id)` trong 30 giây rồi gửi một email. Event đến muộn thì thành email thứ hai — thừa chứ không thiếu.
- Inbox: event được ghi vào bảng `pending_notifications` (`unique(event_id)` chống nhận trùng) rồi mới ack với RabbitMQ.
- Gửi: gửi email trước, đánh dấu `sent_at` sau (at-least-once — trùng còn hơn mất). Nhiều bản notification nhặt việc bằng `FOR UPDATE SKIP LOCKED`.

## 4. Mô hình dữ liệu

### Sở hữu dữ liệu

| Dữ liệu | Service chủ |
|---|---|
| Tài khoản, mật khẩu | identity |
| Vai trò (ai quản lý chi nhánh nào) | authz |
| Chuỗi (tenant): tên, gói dịch vụ | booking |
| Chi nhánh, phòng, giờ mở cửa | booking |
| Booking | booking |
| Gói hội viên | booking — lần đặt lịch nào cũng phải kiểm gói, để chung service thì không thêm bước gọi mạng |
| File ảnh của phòng | storage giữ file, booking giữ tham chiếu (`photo_file_id`) |
| Lịch sử email đã gửi | notification |

- Chỉ service chủ được ghi; service khác gọi API của chủ hoặc giữ bản sao cập nhật qua event.
- Nguyên tắc xoá: dữ liệu nghiệp vụ chỉ **đổi trạng thái**; dữ liệu cá nhân khi người dùng yêu cầu thì **ẩn danh hoá**; dữ liệu kỹ thuật tạm (token, mục chặn, bộ đếm, outbox đã phát) thì **xoá/để tự hết hạn**; file thì đánh dấu rồi dọn theo chính sách.

### Bảng, cột, ràng buộc, index
> Bảng nào, cột chính nào, quan hệ ra sao, ràng buộc (FK, unique, check) và index nào phục vụ query nào.
> Câu còn mở: booking đã huỷ (chỉ đổi trạng thái) không được chiếm slot, nhưng vẫn phải giữ ràng buộc unique chống đặt trùng.

## 5. API
> Bảng: method, path, mô tả, mã lỗi có thể trả.

## 6. Xác thực & phân quyền

### Token
- **Access token** (JWT, identity ký bằng private key) sống **15 phút**. Mọi service tự kiểm chữ ký bằng public key → identity không nằm trên đường nóng; identity chết thì người đã đăng nhập vẫn dùng được.
- **Refresh token** sống **1 tuần**, rotation mỗi lần làm mới; refresh token cũ bị dùng lại → thu hồi cả chuỗi. Lưu trong Redis làm nguồn sự thật (mất dữ liệu chỉ khiến người dùng đăng nhập lại). Gửi qua cookie `httpOnly; Secure; SameSite`, không đặt token trên URL, không log token.

### Danh sách chặn (thu hồi access token)
- Nguồn sự thật: bảng `revocations` trong PostgreSQL của identity.
- Kênh: Redis Stream `revocations`; mỗi bản service tự `XREAD` (phát cho tất cả, không dùng consumer group); stream cắt bớt theo 15 phút.
- Mỗi bản service giữ bản sao trong RAM, kiểm mỗi request không gọi mạng.
- Khởi động: đăng ký nghe trước, nạp sau, **gộp chứ không ghi đè** — thao tác "thêm mục chặn" idempotent và giao hoán nên nhận trùng/lộn thứ tự vẫn đúng.
- Hai kiểu chặn:
  - Đăng xuất thiết bị này: lưu `sid`, chặn khi `token.sid == sid`.
  - Đăng xuất tất cả: lưu `sub` + thời điểm chặn, chặn khi `token.sub == sub` và `token.iat <= thời điểm chặn` (chặn nhầm trong cùng giây còn hơn để lọt; cái giá chỉ là một lần làm mới ngầm).
- Xoá mục chặn lúc `thời điểm chặn + 15 phút + lệch đồng hồ`.
- Booking (Laravel/PHP không giữ biến giữa các request): chạy Octane (Swoole), `Octane::tick` mỗi 5 giây đọc stream vào Octane cache. Trạng thái theo request dùng binding `scoped()`, thiếu tenant thì ném lỗi; tenant lấy từ token đã xác minh *(lời giải mẫu)*. `--max-requests` làm lưới an toàn cho rò bộ nhớ.

### Phân quyền (phương án C)
- Quyền thô (`tenant`, `role`, `branches`) nằm trong access token; identity lấy từ authz lúc cấp/làm mới token.
- Quyền theo tài nguyên kiểm tại booking (chủ dữ liệu): `sub`↔`booking.user_id`, `branches`↔`branch_id`, `tenant`↔`tenant_id`.
- Gỡ quyền: authz phát `role.changed` qua outbox → identity ghi mục chặn kiểu "tất cả" → token cũ bị 401 → web tự làm mới, nhận quyền mới trong vài giây, không phải đăng nhập lại.
- Authz chết lúc làm mới token *(lời giải mẫu)*: identity dùng bản chụp quyền (`roles_snapshot`, `roles_fetched_at`) lưu cùng phiên, tối đa 60 phút tuổi; cấp token suy giảm sống 5 phút có cờ `roles_stale` (hành động nhạy cảm từ chối, đặt/xem lịch cho phép); có mục chặn mới hơn bản chụp thì từ chối.
- Gán quyền: authz gọi đồng bộ sang booking, kiểm chi nhánh tồn tại **và thuộc tenant của người gán**.

### Chống dò mật khẩu
- Bộ đếm đăng nhập sai theo email và theo IP; `INCR` + `EXPIRE` gộp trong `MULTI/EXEC` (Redis không rollback, nhưng client chết trước `EXEC` thì không lệnh nào chạy).
- Cookie thiết bị có chữ ký để nhận ra thiết bị quen; thay khoá cứng bằng chậm dần, CAPTCHA, khoá tạm, hoặc chỉ khoá thiết bị lạ.
- Credential stuffing: làm cả 4 lớp — chặn mật khẩu đã lộ (Have I Been Pwned, k-anonymity), xác minh thiết bị lạ qua email, bộ đếm tỷ lệ sai toàn hệ thống bật CAPTCHA, email báo đăng nhập từ thiết bị mới.
- Không bao giờ lưu mật khẩu, kể cả mật khẩu nhập sai.

## 7. Điểm tranh chấp dữ liệu
> Chuyện gì xảy ra khi 2 người cùng đặt 1 slot? Bạn chọn cách nào (lock, unique, cả hai…) và vì sao?

## 8. Lỗi & trường hợp đặc biệt

| Sự cố | Hành vi |
|---|---|
| Redis chết | Vẫn kiểm bằng danh sách trong RAM (suy giảm có kiểm soát); người bị chặn trong lúc sự cố lọt tối đa `min(thời gian sự cố, 15 phút)` |
| Redis mất dữ liệu | Identity kiểm khoá `revocations:ready` vài giây một lần; mất khoá → phát lại toàn bộ từ DB. Dòng phát lại có ID lớn hơn và thao tác idempotent nên service tự lành, không cần tín hiệu reload |
| Authz chết | Đặt/xem lịch vẫn chạy (quyền nằm trong token); làm mới token theo mục 6 |
| Have I Been Pwned chết | Cho đổi mật khẩu, kiểm lại ở lần đăng nhập kế tiếp bằng chính mật khẩu người dùng nhập |
| Chi nhánh đóng cửa | Booking đánh dấu đã đóng, phát `branch.closed` qua outbox; huỷ booking từ ngày hiệu lực, phát từng `booking.cancelled`; authz vô hiệu vai trò; notification gửi email và huỷ lịch nhắc; booking là chốt chặn cuối cùng nên bản sao trễ vài giây không gây hại |

> Còn lại: retry từ client, membership hết hạn giữa chừng, đặt slot đã qua, huỷ sát giờ, ranh giới 21:00…

## 9. Vận hành
- Rò bộ nhớ: worker Octane tự khởi động lại sau N request; giới hạn RAM cho container.
- Treo: timeout cho mỗi request và mỗi lần gọi ra ngoài; health check `/up` để tự khởi động lại container.
> Log, monitoring, những gì sẽ làm ở các tuần sau (queue, broker).

## 10. Đánh đổi & phương án đã loại

| Quyết định | Chọn | Phương án loại và lý do |
|---|---|---|
| Kiểm token ở đâu | Từng service tự kiểm bằng public key | Gateway kiểm rồi service tin luôn: ai gọi thẳng service trong mạng nội bộ là giả danh được. Hỏi identity mỗi request: identity gánh toàn bộ tải, chết là cả hệ thống ngừng |
| Thời gian sống access token | 15 phút | 1 phút: lệch đồng hồ thành đáng kể, identity bị gọi ~2,5 lần/giây. 24 giờ: token lộ hoặc đã đăng xuất vẫn dùng được 24 giờ |
| Kênh phát danh sách chặn | Redis Stream | Pub/Sub: phát xong là quên, service mất kết nối lỡ tin vĩnh viễn. Tra Redis mỗi request: đưa Redis vào đường nóng |
| Nguồn sự thật danh sách chặn | DB của identity | File riêng từng service: mất khi tạo lại container, các bản lệch nhau |
| Phân quyền | C (quyền thô trong token + kiểm theo tài nguyên tại booking) | A gọi authz mỗi request: authz chết là chức năng chính chết. Chỉ nhúng quyền vào token: quyền "của ai" chỉ booking biết |
| Booking giữ danh sách chặn | Octane | Tra Redis mỗi request: Redis vào đường nóng. APCu: APCu của CLI tách khỏi FPM nên tiến trình nghe stream không đổ dữ liệu vào được |
| Kiểm chi nhánh khi gán quyền | Gọi đồng bộ sang booking | Bản sao qua event: thao tác hiếm, không đáng giữ bản sao. Không kiểm: gán được vào chi nhánh không tồn tại hoặc của chuỗi khác |
| Xoá dữ liệu nghiệp vụ | Đổi trạng thái | Xoá cứng: mất lịch sử booking, báo cáo cũ sai |

## 11. Còn mở
- Ngưỡng đăng nhập sai (mấy lần, trong bao lâu); refresh token có hạn tuyệt đối không; khoá đánh dấu kiểm mấy giây một lần.
- Xác thực giữa các service (authz gọi API nội bộ của booking).
- Saga cho luồng chủ chuỗi tự đăng ký (identity + booking + authz).
- Bảng đồng bộ/bất đồng bộ cho từng cặp service.
