# platform — monorepo NestJS của BranchBook

Bốn service NestJS dùng chung một repo (`apps/`), vai trò theo spec, hiện mỗi app mới chỉ có `GET /health`:

| App | Vai trò |
| --- | --- |
| `identity` | Đăng ký, đăng nhập, cấp/làm mới/thu hồi token, công khai public key |
| `authz` | Gán vai trò theo chuỗi/chi nhánh |
| `notification` | Inbox, gửi email, nhắc lịch |
| `storage` | Upload/download qua presigned URL (kho S3-compatible, chọn ở tuần 7 — MinIO đã ngừng phát hành image) |

Công cụ: Vitest + oxlint + ESM (mặc định NestJS 12), build bằng rspack, pnpm 11.

## Chạy (từ thư mục gốc repo)

```bash
make up-all         # hạ tầng + booking + 4 app NestJS (qua Docker)
make test-platform  # unit + e2e test các app NestJS
```

Các app không mở cổng ra máy host, chỉ truy cập qua gateway Traefik:

- http://localhost:8100/identity/health
- http://localhost:8100/authz/health
- http://localhost:8100/notification/health
- http://localhost:8100/storage/health

## Script (`pnpm <script>` trong `services/platform`)

`build:all`, `typecheck`, `lint`, `format`, `test`, `test:e2e`, `test:cov`, `test:watch`.
