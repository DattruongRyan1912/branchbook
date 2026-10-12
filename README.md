# BranchBook

SaaS đặt lịch cho chuỗi trung tâm nhiều chi nhánh (đa tenant): hội viên xem slot trống, đặt và huỷ lịch, nhận thông báo; quản lý chi nhánh xem lịch real-time; chủ chuỗi tự đăng ký và quản lý chi nhánh.

Dự án học theo lộ trình 10 tuần, xây theo kiến trúc **microservice ngay từ đầu**, tập trung vào: thiết kế hệ thống, chống đặt trùng khi nhiều request đồng thời, xác thực và phân quyền giữa các service, message broker (outbox/inbox), saga, testing, cloud.

**Định hướng sản phẩm:** làm như một SaaS thật — nhiều chuỗi trung tâm (tenant) dùng chung hệ thống, dữ liệu tách theo tenant, có landing page, tài khoản demo và bản deploy công khai. Khách hàng là giả lập; số liệu chỉ lấy từ đo đạc/load test thật.

- Thiết kế (nguồn quyết định kỹ thuật): [`docs/design.md`](docs/design.md)
- Kế hoạch sản phẩm: [`docs/superpowers/specs/2026-10-13-branchbook-product-plan.html`](docs/superpowers/specs/2026-10-13-branchbook-product-plan.html)

## Kiến trúc (đích)

```
                         Traefik (gateway)
        ┌──────────┬──────────┬───┴──────┬──────────────┬──────────┐
       web      identity     authz     booking      notification  storage
     Next.js     NestJS      NestJS    Laravel        NestJS       NestJS
               PostgreSQL  PostgreSQL MySQL+Redis   PostgreSQL   kho S3 (tuần 7)
                                          └── outbox ──▶ RabbitMQ ──▶ notification
```

Hiện có: booking, gateway Traefik và 4 app NestJS mới có `/health`; `web/` có từ tuần 3, kho S3 từ tuần 7.

| Thư mục | Nội dung |
|---|---|
| `services/booking/` | Laravel 13 / PHP 8.4 / Pest 5 — chuỗi, chi nhánh, phòng, slot, gói hội viên, đặt/huỷ |
| `services/platform/` | NestJS 12 monorepo (Vitest, oxlint, ESM) — `apps/{identity,authz,notification,storage}` |
| `gateway/` | Cấu hình Traefik |
| `infra/` | Script khởi tạo MySQL, PostgreSQL |

## Chạy local

Yêu cầu: Docker. Không cần cài PHP trên máy.

Lần đầu sau khi clone:

```bash
make setup
make up && make fresh
```

```bash
make               # liệt kê các lệnh (make help)
make setup         # lần đầu sau khi clone: .env, vendor, APP_KEY
make up            # hạ tầng + booking → http://localhost:8180/up, gateway http://localhost:8100/booking/up
make up-all        # thêm identity, authz, notification, storage → http://localhost:8100/<service>/health
make test          # Pest của booking trên MySQL branchbook_testing
make test-platform # type-check + lint + unit + e2e test các service NestJS
make keys          # sinh cặp khoá RSA dev để ký/kiểm JWT (tuần 1); đã có thì giữ nguyên
make pg-init       # chạy lại init PostgreSQL khi thêm service/DB mới
make fresh         # tạo lại database booking + seed
make down          # dừng tất cả
```

| Dịch vụ | Địa chỉ từ máy | Ghi chú |
|---|---|---|
| Gateway (Traefik) | `http://localhost:8100` | `/booking`, `/identity`, `/authz`, `/notification`, `/storage` |
| Traefik dashboard | `http://localhost:8101` | |
| Booking (trực tiếp) | `http://localhost:8180` | |
| MySQL | `127.0.0.1:13306` | `branchbook` / `branchbook` |
| Redis | `127.0.0.1:16379` | |
| PostgreSQL | `127.0.0.1:15432` | mỗi service một user + DB: `identity`, `authz`, `notification` (mật khẩu = tên) |
| RabbitMQ | `127.0.0.1:35672`, giao diện `http://localhost:35673` | `branchbook` / `branchbook` |
| Mailpit | SMTP `127.0.0.1:11025`, giao diện `http://localhost:18025` | |

## Tiến độ

### Tuần 0 — Hoàn tất thiết kế
- [x] Hạ tầng ban đầu: Laravel 13, Pest, MySQL cho test
- [x] Khung microservice: `services/booking`, NestJS monorepo, PostgreSQL, RabbitMQ, Mailpit, Traefik, CI
- [ ] B1. Design doc đủ 11 mục + ADR-0001, ADR-0002 + tự trình bày 10 phút

### Tuần 1 — Booking core
- [ ] B2. Schema đa tenant, model, factory, seeder
- [ ] B3. Xác thực JWT (khoá dev) + API xem chi nhánh và slot trống
- [ ] B4. Đặt lịch chống trùng (409)
- [ ] B5. Huỷ lịch (Policy) + Idempotency-Key
- [ ] B6. ≥ 15 test + thử N request đồng thời
- [ ] B7. Tổng kết tuần

### Tuần 2–10
Identity · Web + demo v0.1 · Thu hồi token + chống dò mật khẩu · Broker + notification · Authz · Saga + storage + đóng chi nhánh (demo v1.0) · Real-time + E2E + quan sát · AWS · K8s + AI + portfolio.

## Số liệu đo được
_Cập nhật khi hoàn thành từng phần (chỉ ghi số liệu đo thật)._
