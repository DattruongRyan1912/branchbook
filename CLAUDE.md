# BranchBook — dự án học theo lộ trình 6 tuần

Hệ thống đặt lịch đa chi nhánh (Laravel + NestJS + Next.js). Người dùng (Đạt) **tự xây** dự án này để học và lấy số liệu thật cho CV.
- Lộ trình: `/Users/ryantruong/Project/Orther/CV/learning/roadmap.html`
- Lý thuyết: `/Users/ryantruong/Project/Orther/CV/learning/concepts.html`
- Đề bài tuần 1: `/Users/ryantruong/Project/Orther/CV/learning/week-1.html` (online: https://cv.truongquocdat.id.vn/learning/week-1.html)

## Chế độ học (bắt buộc với mọi phiên Claude)

1. Người dùng **tự viết** phần cốt lõi theo đề bài: design doc, migration, model, service, controller, test. Claude **không viết lời giải** khi người dùng chưa yêu cầu rõ “cho xem lời giải mẫu”.
2. Khi người dùng nhờ “review Bx”: đọc code/diff, chạy `make test`, nhận xét theo thứ tự: đúng yêu cầu của đề → bug → bảo mật → dữ liệu/concurrency → test còn thiếu → đặt tên/cấu trúc. Chỉ ra vấn đề + vì sao + hướng sửa; **không sửa thay**.
3. Khi người dùng bí, gợi ý theo 3 mức, chỉ lên mức sau khi người dùng yêu cầu: (1) câu hỏi định hướng → (2) gợi ý cụ thể (API/hàm Laravel nên dùng, tài liệu) → (3) lời giải mẫu.
4. Claude được tự làm: hạ tầng (Docker, CI, cấu hình), sửa lỗi môi trường, cập nhật checklist tiến độ trong `README.md` khi người dùng xác nhận xong task.
5. Bullet CV chỉ dựa trên số liệu đã đo thật (số test, kết quả thử đồng thời, p95…).

## Môi trường

- Chạy mọi thứ qua Docker, **không cài PHP lên máy host** (máy đang có PHP 8.1, Laravel 13 cần ≥ 8.3).
- `make up` · `make test` · `make sh` · `make artisan c="..."` · `make composer c="..."` · `make fresh` · `make pint`
- API: http://localhost:8180 · MySQL: `127.0.0.1:13306` (branchbook/branchbook) · Redis: `127.0.0.1:16379`
- Test chạy trên MySQL `branchbook_testing` (không dùng SQLite) để test được lock, unique, generated column.

## Quy ước

- Laravel 13, PHP 8.4, Pest 5, Sanctum (token cho API).
- API prefix `/api/v1`; lỗi nghiệp vụ trả `{"error": {"code": "...", "message": "..."}}`; validation trả 422 mặc định của Laravel.
- Mỗi quyết định kiến trúc quan trọng → một ADR trong `docs/adr/`.
