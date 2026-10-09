# BranchBook

Hệ thống đặt lịch đa chi nhánh (phòng/khung giờ) cho chuỗi trung tâm: hội viên xem slot trống, đặt và huỷ lịch, nhận thông báo; quản lý chi nhánh xem lịch real-time.

Dự án học tập theo lộ trình 6 tuần, tập trung vào: thiết kế hệ thống, chống đặt trùng khi có nhiều request đồng thời, testing, queue, message broker, cloud.

## Kiến trúc (dự kiến)

```
web (Next.js) ──▶ core-api (Laravel 13) ──outbox──▶ RabbitMQ ──▶ notifier (NestJS) ──WebSocket──▶ web
                     │  MySQL · Redis                               │  PostgreSQL
```

## Chạy local

Yêu cầu: Docker.

```bash
make up            # mysql, redis, core-api → http://localhost:8180/up
make test          # chạy Pest trên MySQL branchbook_testing
make fresh         # tạo lại database + seed
```

## Tiến độ

### Tuần 1 — System Design + Laravel core có test
- [x] B0. Hạ tầng: Docker Compose, Laravel 13, Sanctum, Pest, MySQL cho test
- [ ] B1. Design doc (`docs/design.md`) + ADR-0001
- [ ] B2. Schema, model, factory, seeder
- [ ] B3. API xem chi nhánh và slot trống
- [ ] B4. API đặt lịch chống trùng (409)
- [ ] B5. Huỷ lịch (Policy) + Idempotency-Key
- [ ] B6. ≥ 15 test + thử 20 request đồng thời
- [ ] B7. Tổng kết tuần

### Tuần 2–6
Testing chuyên sâu + CI + Queue · RabbitMQ + Outbox + NestJS · Next.js + Real-time + E2E · AWS · Kubernetes + AI.

## Số liệu đo được
_Cập nhật khi hoàn thành từng phần (chỉ ghi số liệu đo thật)._
