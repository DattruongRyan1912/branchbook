# BranchBook — dự án học theo lộ trình 10 tuần (microservice)

SaaS đặt lịch đa tenant cho chuỗi trung tâm (Laravel + NestJS + Next.js), kiến trúc microservice ngay từ đầu. Người dùng (Đạt) **tự xây** dự án này để học và lấy số liệu thật cho CV.
- **Định hướng (chốt 2026-10-10, mở rộng 2026-10-13):** product SaaS đa tenant, khách hàng giả lập (chuỗi trung tâm âm nhạc), có landing + tài khoản demo + deploy công khai để mang đi phỏng vấn. Microservice ngay từ đầu: booking (Laravel), identity/authz/notification/storage (NestJS monorepo), gateway Traefik.
- Nguồn quyết định kỹ thuật: `docs/design.md`. Kế hoạch sản phẩm + lịch tuần: `docs/superpowers/specs/2026-10-13-branchbook-product-plan.html`.
- Lộ trình: `/Users/ryantruong/Project/Orther/CV/content/learn/roadmap/` (online: https://cv.truongquocdat.id.vn/learn/roadmap/)
- Lý thuyết: `/Users/ryantruong/Project/Orther/CV/content/learn/concepts/` (online: https://cv.truongquocdat.id.vn/learn/concepts/)
- Đề bài tuần 1: `/Users/ryantruong/Project/Orther/CV/content/learn/week-1/` (online: https://cv.truongquocdat.id.vn/learn/week-1/)

## Chế độ học (bắt buộc với mọi phiên Claude)

1. Người dùng **tự viết** phần cốt lõi theo đề bài: design doc, migration, model, service, controller, middleware xác thực, test. Claude **không viết lời giải** khi người dùng chưa yêu cầu rõ “cho xem lời giải mẫu”.
2. Khi người dùng nhờ “review Bx”: đọc code/diff, chạy test, nhận xét theo thứ tự: đúng yêu cầu của đề → bug → bảo mật → dữ liệu/concurrency → test còn thiếu → đặt tên/cấu trúc. Chỉ ra vấn đề + vì sao + hướng sửa; **không sửa thay**.
3. Khi người dùng bí, gợi ý theo 3 mức, chỉ lên mức sau khi người dùng yêu cầu: (1) câu hỏi định hướng → (2) gợi ý cụ thể (API/hàm nên dùng, tài liệu) → (3) lời giải mẫu.
4. Claude được tự làm: hạ tầng (Docker, CI, Traefik, cấu hình), sửa lỗi môi trường, landing/demo, đề bài và trang lý thuyết, cập nhật checklist tiến độ trong `README.md` khi người dùng xác nhận xong task, ghi câu trả lời hỏi–đáp thiết kế vào `docs/design.md`. Các thay đổi này **mặc định tự commit + push** khi test xanh, không hỏi lại (người dùng yêu cầu 2026-10-10).
5. Bullet CV chỉ dựa trên số liệu đã đo thật (số test, kết quả thử đồng thời, p95…).
6. Đào sâu hơn làm nhanh: khi người dùng muốn hiểu kỹ một câu hỏi thiết kế, không đề xuất bỏ qua hay dời sang tuần sau.

## Môi trường

- Chạy mọi thứ qua Docker, **không cài PHP lên máy host** (máy đang có PHP 8.1, Laravel 13 cần ≥ 8.3). Node 24 + pnpm 11 có trên host cho `services/platform`.
- `make` (liệt kê lệnh) · `make up` · `make up-all` · `make test` · `make test-platform` · `make keys` · `make pg-init` · `make sh` · `make artisan c="..."` · `make composer c="..."` · `make fresh` · `make pint` · `make logs s=<service>`
- Booking trực tiếp http://localhost:8180 · Gateway http://localhost:8100/<service> (Traefik, dashboard 8101) · MySQL `127.0.0.1:13306` (branchbook/branchbook) · Redis `127.0.0.1:16379` · PostgreSQL `127.0.0.1:15432` · RabbitMQ `127.0.0.1:35672` (UI 35673) · Mailpit UI 18025
- Test booking chạy trên MySQL `branchbook_testing` (không dùng SQLite) để test được lock, unique, generated column. Test NestJS dùng database `<service>_testing` trên PostgreSQL.

## Quy ước

- Booking: Laravel 13, PHP 8.4, Pest 5. Platform: NestJS 12, pnpm, Vitest + oxlint (ESM, mặc định của NestJS 12), `pnpm typecheck` vì build rspack không kiểm kiểu; mỗi app một database + user PostgreSQL riêng, không truy vấn chéo.
- Xác thực: JWT RS256 do identity cấp; mỗi service tự kiểm bằng public key. Tuần 1 dùng cặp khoá dev (`make keys`, không commit).
- API prefix `/api/v1`; lỗi nghiệp vụ trả `{"error": {"code": "...", "message": "..."}}`; validation trả 422 mặc định của Laravel.
- Kho file S3-compatible chọn ở tuần 7 (MinIO đã ngừng phát hành image).
- Mỗi quyết định kiến trúc quan trọng → một ADR trong `docs/adr/`.
