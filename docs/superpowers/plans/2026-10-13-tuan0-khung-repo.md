# Tuần 0 — Khung repo microservice BranchBook: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển repo BranchBook từ một app Laravel sang khung microservice chạy được: `services/booking` (Laravel), `services/platform` (NestJS monorepo 4 app có `/health`), Compose đủ hạ tầng sau gateway Traefik, CI chạy test PHP + Node.

**Architecture:** Booking giữ nguyên code Laravel, chỉ đổi đường dẫn. Bốn app NestJS (identity, authz, notification, storage) nằm chung một monorepo, mỗi app chạy một container riêng từ cùng một image dev, bật bằng Compose profile `platform`. Traefik định tuyến theo tiền tố path (`/booking`, `/identity`, …) và bỏ tiền tố trước khi chuyển tiếp. Mỗi service có database + user PostgreSQL riêng, quyền CONNECT chéo bị thu hồi.

**Tech Stack:** Docker Compose, Laravel 13 / PHP 8.4 / Pest 5, NestJS 12 / Node 24 / pnpm 11.5.2 / Vitest + oxlint (ESM), PostgreSQL 17, RabbitMQ 4, Mailpit, Traefik v3, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-13-branchbook-product-plan.html` (Phần 2, Phần 3 tuần 0).

---

## Ghi chú cho người thực hiện

- Repo: `/Users/ryantruong/Project/Orther/branchbook`. Mọi lệnh chạy từ thư mục gốc repo trừ khi ghi khác. Agent chạy lệnh shell với tiền tố `rtk` (quy ước của người dùng), ví dụ `rtk git status`.
- **Không cài PHP lên máy host** (máy có PHP 8.1). Lệnh PHP chạy trong container qua `make` hoặc `docker compose exec booking …`. Node 24 + pnpm 11.5.2 có sẵn trên host.
- **Chế độ học:** kế hoạch này chỉ làm phần vỏ. KHÔNG viết logic nghiệp vụ, schema nghiệp vụ, middleware JWT, test nghiệp vụ — đó là bài của người dùng (B2–B6). Các app NestJS chỉ có `/health`.
- **MinIO không đưa vào Compose:** image `minio/minio` đã ngừng phát hành (Docker Hub archive 09/2026). Kho S3-compatible chọn ở tuần 7 (RustFS / Garage / SeaweedFS). Task 7 ghi chú điều này vào spec và design.md.
- `libs/{auth,messaging,logging}` **không tạo trước** (YAGNI): người dùng tạo bằng `nest generate library` khi cần (tuần 2, 5, 8).
- Commit sau mỗi task; push ở Task 6 và Task 7 (người dùng cho phép Claude tự push phần hạ tầng khi test xanh).

## Cấu trúc file sau kế hoạch

```
branchbook/
├─ docker-compose.yml          # sửa: booking, postgres, rabbitmq, mailpit, traefik, platform-*
├─ Makefile                    # viết lại: up, up-all, test, test-platform, keys…
├─ README.md, CLAUDE.md        # viết lại theo kiến trúc mới
├─ .github/workflows/ci.yml    # mới: job booking + job platform
├─ gateway/traefik.yml         # mới: cấu hình tĩnh Traefik
├─ infra/
│  ├─ mysql/init.sql           # giữ nguyên
│  └─ postgres/init.sql        # mới: user + DB riêng mỗi service
├─ services/
│  ├─ booking/                 # đổi tên từ core-api/ (Dockerfile thêm openssl, .gitignore thêm storage/keys)
│  └─ platform/                # mới: NestJS monorepo
│     ├─ Dockerfile, .dockerignore
│     ├─ nest-cli.json, package.json, pnpm-lock.yaml, pnpm-workspace.yaml (nếu pnpm cần)
│     ├─ jest-e2e.json
│     └─ apps/{identity,authz,notification,storage}/
│        ├─ src/main.ts, src/<app>.module.ts, src/<app>.controller.ts
│        ├─ test/app.e2e-spec.ts
│        └─ tsconfig.app.json
└─ docs/ (design.md, specs/…html — sửa ghi chú storage)
```

---

### Task 1: Đổi `core-api/` thành `services/booking/`

**Files:**
- Move: `core-api/` → `services/booking/`
- Modify: `docker-compose.yml` (khối `core-api`)
- Modify: `Makefile` (tên service)
- Modify: `services/booking/Dockerfile:1` (comment)

- [ ] **Step 1: Dừng container cũ**

Run: `docker compose down`
Expected: các container `branchbook-core-api-1`, `branchbook-mysql-1`, `branchbook-redis-1` bị xoá (volume `mysql-data` giữ nguyên).

- [ ] **Step 2: Đổi tên thư mục**

```bash
mkdir -p services
git mv core-api services/booking
```

Kiểm tra file không theo dõi bởi git (`vendor/`, `.env`) đã đi theo:

Run: `test ! -e core-api && ls services/booking/vendor/autoload.php services/booking/.env`
Expected: in ra 2 đường dẫn, không lỗi. Nếu `core-api/` vẫn còn (chứa `vendor/`, `.env`), chạy `mv core-api/vendor core-api/.env services/booking/ && rmdir core-api` rồi kiểm tra lại.

- [ ] **Step 3: Sửa khối service trong `docker-compose.yml`**

Thay toàn bộ khối `core-api:` bằng:

```yaml
  booking:
    build: ./services/booking
    volumes: ["./services/booking:/app"]
    ports: ["8180:8000"]
    environment:
      PHP_CLI_SERVER_WORKERS: 8   # artisan serve xử lý song song (cần cho bài thử đồng thời B6)
    depends_on:
      mysql: { condition: service_healthy }
      redis: { condition: service_started }
```

- [ ] **Step 4: Sửa Makefile và comment Dockerfile**

```bash
sed -i '' 's/core-api/booking/g' Makefile
sed -i '' 's/Image dev cho core-api/Image dev cho booking/' services/booking/Dockerfile
```

Run: `grep -c core-api Makefile services/booking/Dockerfile docker-compose.yml`
Expected: cả 3 file đều `0`.

- [ ] **Step 5: Chạy lại và kiểm tra**

```bash
docker compose up -d --build
sleep 15
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8180/up
make test
```

Expected: `200`; Pest báo `2 passed` (ExampleTest Unit + Feature).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(infra): đổi core-api thành services/booking"
```

---

### Task 2: PostgreSQL (DB riêng mỗi service), RabbitMQ, Mailpit

**Files:**
- Create: `infra/postgres/init.sql`
- Modify: `docker-compose.yml` (thêm 3 service + 2 volume)

- [ ] **Step 1: Viết `infra/postgres/init.sql`**

```sql
-- Mỗi service NestJS một user + database riêng (dev). Thu hồi CONNECT của PUBLIC
-- để service này không kết nối được vào database của service khác.
CREATE USER identity WITH PASSWORD 'identity';
CREATE DATABASE identity OWNER identity;
CREATE DATABASE identity_testing OWNER identity;

CREATE USER authz WITH PASSWORD 'authz';
CREATE DATABASE authz OWNER authz;
CREATE DATABASE authz_testing OWNER authz;

CREATE USER notification WITH PASSWORD 'notification';
CREATE DATABASE notification OWNER notification;
CREATE DATABASE notification_testing OWNER notification;

REVOKE CONNECT ON DATABASE identity, identity_testing FROM PUBLIC;
REVOKE CONNECT ON DATABASE authz, authz_testing FROM PUBLIC;
REVOKE CONNECT ON DATABASE notification, notification_testing FROM PUBLIC;
```

- [ ] **Step 2: Thêm service vào `docker-compose.yml`**

Thêm sau khối `redis:` (trước `booking:`):

```yaml
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_PASSWORD: postgres        # chỉ dùng cho môi trường dev local
    ports: ["15432:5432"]
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./infra/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 5s
      retries: 20

  rabbitmq:
    image: rabbitmq:4-management-alpine
    environment:
      RABBITMQ_DEFAULT_USER: branchbook   # guest chỉ đăng nhập được từ localhost trong container
      RABBITMQ_DEFAULT_PASS: branchbook   # chỉ dùng cho môi trường dev local
    ports: ["127.0.0.1:35672:5672", "127.0.0.1:35673:15672"]
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      retries: 20

  mailpit:
    image: axllent/mailpit:latest
    ports: ["11025:1025", "18025:8025"]   # SMTP, giao diện web
```

Sửa khối `volumes:` cuối file thành:

```yaml
volumes:
  mysql-data:
  postgres-data:
  rabbitmq-data:
```

- [ ] **Step 3: Khởi động và chờ healthy**

```bash
docker compose up -d postgres rabbitmq mailpit
sleep 25
docker compose ps postgres rabbitmq mailpit
```

Expected: `postgres` và `rabbitmq` ở trạng thái `(healthy)`, `mailpit` ở `Up`.

- [ ] **Step 4: Kiểm tra database đã tạo**

Run:
```bash
docker compose exec postgres psql -U postgres -tAc "select datname from pg_database where datname not in ('postgres','template0','template1') order by 1"
```
Expected (6 dòng):
```
authz
authz_testing
identity
identity_testing
notification
notification_testing
```

- [ ] **Step 5: Kiểm tra cô lập giữa các service**

Run: `docker compose exec -e PGPASSWORD=authz postgres psql -h 127.0.0.1 -U authz -d identity -c 'select 1'`
Expected: lỗi chứa `permission denied for database "identity"`.

Run: `docker compose exec -e PGPASSWORD=authz postgres psql -h 127.0.0.1 -U authz -d authz -tAc 'select 1'`
Expected: `1`.

- [ ] **Step 6: Kiểm tra RabbitMQ và Mailpit**

Run: `curl -s -u branchbook:branchbook http://localhost:35673/api/overview | python3 -c "import sys,json; print(json.load(sys.stdin)['rabbitmq_version'])"`
Expected: một phiên bản bắt đầu bằng `4.`

Run: `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:18025/`
Expected: `200`

- [ ] **Step 7: Commit**

```bash
git add infra/postgres/init.sql docker-compose.yml
git commit -m "chore(infra): thêm PostgreSQL (DB riêng mỗi service), RabbitMQ, Mailpit"
```

---

> **Đã chỉnh sau review Task 2 (2026-10-13):** RabbitMQ có `hostname: rabbitmq`, image `rabbitmq:4.3-management-alpine`, healthcheck `check_port_connectivity`, cổng host `35672/35673`; PostgreSQL healthcheck `pg_isready -h 127.0.0.1`; `init.sql` viết lại dạng idempotent (`\gexec`); mọi cổng host bind `127.0.0.1`; Mailpit pin theo minor. Xem commit sửa sau `bd4434d`.

---

### Task 3: Gateway Traefik trước booking

**Files:**
- Create: `gateway/traefik.yml`
- Modify: `docker-compose.yml` (service `traefik`, nhãn cho `booking`)

- [ ] **Step 1: Viết `gateway/traefik.yml`**

```yaml
# Cấu hình tĩnh Traefik (dev). Route khai báo bằng label trên từng service trong docker-compose.yml.
entryPoints:
  web:
    address: ":80"

providers:
  docker:
    exposedByDefault: false   # chỉ service có label traefik.enable=true mới được định tuyến

api:
  dashboard: true
  insecure: true              # dashboard ở cổng 8080 trong container — chỉ dùng cho dev

log:
  level: INFO
```

- [ ] **Step 2: Thêm service `traefik` vào `docker-compose.yml`**

Thêm sau khối `mailpit:`:

```yaml
  traefik:
    image: traefik:v3.7
    ports: ["127.0.0.1:8100:80", "127.0.0.1:8101:8080"]   # gateway, dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./gateway/traefik.yml:/etc/traefik/traefik.yml:ro
```

- [ ] **Step 3: Gắn nhãn định tuyến cho `booking`**

Thêm vào khối `booking:` (cùng cấp với `depends_on`):

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.booking.rule=Path(`/booking`) || PathPrefix(`/booking/`)"
      - "traefik.http.routers.booking.middlewares=booking-strip"
      - "traefik.http.middlewares.booking-strip.stripprefix.prefixes=/booking"
      - "traefik.http.services.booking.loadbalancer.server.port=8000"
```

- [ ] **Step 4: Chạy và kiểm tra**

```bash
docker compose up -d
sleep 10
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8100/booking/up
curl -s http://localhost:8101/api/http/routers | python3 -c "import sys,json; print(sorted(r['name'] for r in json.load(sys.stdin)))"
```

Expected: `200`; danh sách router có `booking@docker`.

- [ ] **Step 5: Commit**

```bash
git add gateway/traefik.yml docker-compose.yml
git commit -m "chore(infra): thêm gateway Traefik, định tuyến /booking"
```

---

> **Đã chỉnh sau review Task 3 (2026-10-13):** image `traefik:v3.7`; rule dạng ``Path(`/x`) || PathPrefix(`/x/`)`` (PathPrefix trơn bắt cả `/xyz`); `traefik.yml` thêm `global` tắt kiểm tra phiên bản, `aliasHeadersStrategy: delete`, chặn ký tự mã hoá trong path, `constraints` theo project compose, `accessLog`. Xem commit sửa sau `4340b59`.

---

### Task 4: NestJS monorepo `services/platform` với 4 app có `/health`

**Files:**
- Create: `services/platform/**` (scaffold bằng Nest CLI)
- Create: `services/platform/jest-e2e.json`, `services/platform/Dockerfile`, `services/platform/.dockerignore`
- Create/Overwrite: `services/platform/apps/<app>/src/{main.ts,<app>.module.ts,<app>.controller.ts}`, `services/platform/apps/<app>/test/app.e2e-spec.ts` cho `identity`, `authz`, `notification`, `storage`
- Modify: `services/platform/nest-cli.json`, `services/platform/package.json`
- Modify: `docker-compose.yml` (service `platform-deps`, `identity`, `authz`, `notification`, `storage`, volume `platform-node-modules`)

- [ ] **Step 1: Scaffold project**

```bash
cd services
pnpm dlx @nestjs/cli@12.0.8 new platform --package-manager pnpm --skip-git --strict
cd platform
```

Expected: thư mục `services/platform` có `src/`, `test/`, `package.json`, `pnpm-lock.yaml`, `nest-cli.json`, `.gitignore` (chứa `node_modules` và `dist`).

Nếu `pnpm install` báo package có build script bị chặn (pnpm 11 — thông báo về `allowBuilds`/ignored builds), tạo `services/platform/pnpm-workspace.yaml` liệt kê đúng các package được báo, mặc định không cho chạy:

```yaml
allowBuilds:
  <tên-package-được-báo>: false
```

rồi chạy lại `pnpm install` tới khi thoát mã 0. (Repo CV đang dùng đúng cách này: `sharp: false`, `unrs-resolver: false`.)

- [ ] **Step 2: Chuyển sang monorepo và tạo 4 app**

```bash
pnpm nest generate app identity
pnpm nest generate app authz
pnpm nest generate app notification
pnpm nest generate app storage
ls apps
```

Expected: `authz identity notification platform storage`.

- [ ] **Step 3: Bỏ app mặc định `platform`**

Xoá app mặc định và sửa `nest-cli.json` bằng script (giữ nguyên các khoá khác mà Nest 12 sinh ra, ví dụ builder):

```bash
rm -rf apps/platform
node -e '
const fs = require("fs");
const f = "nest-cli.json";
const c = JSON.parse(fs.readFileSync(f, "utf8"));
delete c.projects.platform;
c.root = "apps/identity";
c.sourceRoot = "apps/identity/src";
c.compilerOptions = { ...c.compilerOptions, tsConfigPath: "apps/identity/tsconfig.app.json" };
fs.writeFileSync(f, JSON.stringify(c, null, 2) + "\n");
'
node -e 'const c=require("./nest-cli.json"); console.log(c.monorepo, c.root, Object.keys(c.projects).sort().join(","))'
```

Expected: `true apps/identity authz,identity,notification,storage`

- [ ] **Step 4: Sửa `package.json`**

Đặt `packageManager` và thay khối `scripts` (giữ nguyên các trường khác, kể cả cấu hình `jest`):

```bash
node -e '
const fs = require("fs");
const f = "package.json";
const p = JSON.parse(fs.readFileSync(f, "utf8"));
p.packageManager = "pnpm@11.5.2";
p.scripts = {
  "build": "nest build",
  "build:all": "nest build identity && nest build authz && nest build notification && nest build storage",
  "format": "prettier --write \"apps/**/*.ts\" \"libs/**/*.ts\"",
  "start": "nest start",
  "start:dev": "nest start --watch",
  "lint": "eslint \"{apps,libs}/**/*.ts\"",
  "test": "jest --passWithNoTests",
  "test:watch": "jest --watch",
  "test:cov": "jest --coverage --passWithNoTests",
  "test:e2e": "jest --config ./jest-e2e.json"
};
fs.writeFileSync(f, JSON.stringify(p, null, 2) + "\n");
'
node -e 'const p=require("./package.json"); console.log(p.packageManager, Object.keys(p.scripts).join(","))'
```

Expected: `pnpm@11.5.2 build,build:all,format,start,start:dev,lint,test,test:watch,test:cov,test:e2e`

- [ ] **Step 5: Gom cấu hình e2e về một file ở gốc**

Xem file Nest sinh ra: `cat apps/identity/test/jest-e2e.json`. Tạo `services/platform/jest-e2e.json` với nội dung dưới đây; **giữ nguyên khối `transform` như file Nest sinh ra** nếu nó khác `ts-jest` (ví dụ `@swc/jest`):

```json
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": ".",
  "testEnvironment": "node",
  "testRegex": "apps/.+/test/.+\\.e2e-spec\\.ts$",
  "transform": { "^.+\\.(t|j)s$": "ts-jest" }
}
```

Rồi xoá file cấu hình riêng của từng app:

```bash
rm apps/*/test/jest-e2e.json
```

- [ ] **Step 6: Viết test e2e `/health` cho identity (thất bại trước)**

Ghi đè `apps/identity/test/app.e2e-spec.ts`:

```ts
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { IdentityModule } from '../src/identity.module';

describe('identity /health', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [IdentityModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health trả 200 kèm tên service', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ status: 'ok', service: 'identity' });
  });
});
```

(Nếu TypeScript báo `supertest` không có default export, đổi dòng import thành `import * as request from 'supertest';` cho cả 4 file test.)

- [ ] **Step 7: Chạy test, xác nhận thất bại**

Run: `pnpm test:e2e`
Expected: FAIL ở `identity /health` — `expected 200 "OK", got 404 "Not Found"`.

- [ ] **Step 8: Hiện thực `/health` cho identity**

```bash
rm apps/identity/src/identity.service.ts apps/identity/src/identity.controller.spec.ts
```

Ghi đè `apps/identity/src/identity.controller.ts`:

```ts
import { Controller, Get } from '@nestjs/common';

@Controller()
export class IdentityController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'identity' };
  }
}
```

Ghi đè `apps/identity/src/identity.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { IdentityController } from './identity.controller';

@Module({ controllers: [IdentityController] })
export class IdentityModule {}
```

Ghi đè `apps/identity/src/main.ts`:

```ts
import { NestFactory } from '@nestjs/core';
import { IdentityModule } from './identity.module';

async function bootstrap() {
  const app = await NestFactory.create(IdentityModule);
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
```

- [ ] **Step 9: Chạy test, xác nhận identity qua**

Run: `pnpm test:e2e`
Expected: `identity /health` PASS. (Các app còn lại vẫn đang dùng test mặc định `GET /` của Nest — xử lý ở các bước sau.)

- [ ] **Step 10: authz — test trước**

Ghi đè `apps/authz/test/app.e2e-spec.ts`:

```ts
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthzModule } from '../src/authz.module';

describe('authz /health', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AuthzModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health trả 200 kèm tên service', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ status: 'ok', service: 'authz' });
  });
});
```

Run: `pnpm test:e2e -t authz`
Expected: FAIL — `got 404 "Not Found"`.

- [ ] **Step 11: authz — hiện thực**

```bash
rm apps/authz/src/authz.service.ts apps/authz/src/authz.controller.spec.ts
```

`apps/authz/src/authz.controller.ts`:

```ts
import { Controller, Get } from '@nestjs/common';

@Controller()
export class AuthzController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'authz' };
  }
}
```

`apps/authz/src/authz.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { AuthzController } from './authz.controller';

@Module({ controllers: [AuthzController] })
export class AuthzModule {}
```

`apps/authz/src/main.ts`:

```ts
import { NestFactory } from '@nestjs/core';
import { AuthzModule } from './authz.module';

async function bootstrap() {
  const app = await NestFactory.create(AuthzModule);
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
```

Run: `pnpm test:e2e -t authz`
Expected: PASS.

- [ ] **Step 12: notification — test trước**

Ghi đè `apps/notification/test/app.e2e-spec.ts`:

```ts
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { NotificationModule } from '../src/notification.module';

describe('notification /health', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [NotificationModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health trả 200 kèm tên service', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ status: 'ok', service: 'notification' });
  });
});
```

Run: `pnpm test:e2e -t notification`
Expected: FAIL — `got 404 "Not Found"`.

- [ ] **Step 13: notification — hiện thực**

```bash
rm apps/notification/src/notification.service.ts apps/notification/src/notification.controller.spec.ts
```

`apps/notification/src/notification.controller.ts`:

```ts
import { Controller, Get } from '@nestjs/common';

@Controller()
export class NotificationController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'notification' };
  }
}
```

`apps/notification/src/notification.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { NotificationController } from './notification.controller';

@Module({ controllers: [NotificationController] })
export class NotificationModule {}
```

`apps/notification/src/main.ts`:

```ts
import { NestFactory } from '@nestjs/core';
import { NotificationModule } from './notification.module';

async function bootstrap() {
  const app = await NestFactory.create(NotificationModule);
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
```

Run: `pnpm test:e2e -t notification`
Expected: PASS.

- [ ] **Step 14: storage — test trước**

Ghi đè `apps/storage/test/app.e2e-spec.ts`:

```ts
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { StorageModule } from '../src/storage.module';

describe('storage /health', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [StorageModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health trả 200 kèm tên service', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ status: 'ok', service: 'storage' });
  });
});
```

Run: `pnpm test:e2e -t storage`
Expected: FAIL — `got 404 "Not Found"`.

- [ ] **Step 15: storage — hiện thực**

```bash
rm apps/storage/src/storage.service.ts apps/storage/src/storage.controller.spec.ts
```

`apps/storage/src/storage.controller.ts`:

```ts
import { Controller, Get } from '@nestjs/common';

@Controller()
export class StorageController {
  @Get('health')
  health() {
    return { status: 'ok', service: 'storage' };
  }
}
```

`apps/storage/src/storage.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { StorageController } from './storage.controller';

@Module({ controllers: [StorageController] })
export class StorageModule {}
```

`apps/storage/src/main.ts`:

```ts
import { NestFactory } from '@nestjs/core';
import { StorageModule } from './storage.module';

async function bootstrap() {
  const app = await NestFactory.create(StorageModule);
  app.enableShutdownHooks();
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
```

Run: `pnpm test:e2e -t storage`
Expected: PASS.

- [ ] **Step 16: Chạy toàn bộ trên host**

```bash
pnpm build:all && pnpm test && pnpm test:e2e && pnpm lint
```

Expected: build 4 app không lỗi (`dist/apps/{identity,authz,notification,storage}/main.js` tồn tại); `pnpm test` thoát 0 (không có unit test); `pnpm test:e2e` báo `Tests: 4 passed`; lint không lỗi. Nếu lint báo lỗi format ở file mới, chạy `pnpm format` rồi chạy lại.

- [ ] **Step 17: Dockerfile dev cho platform**

`services/platform/Dockerfile`:

```dockerfile
# Image dev cho các app NestJS trong monorepo. Chọn app bằng biến APP (identity, authz, notification, storage).
FROM node:24-alpine

RUN npm install -g pnpm@11.5.2

WORKDIR /app
EXPOSE 3000
CMD ["sh", "-c", "pnpm nest start ${APP} --watch"]
```

`services/platform/.dockerignore`:

```
node_modules
dist
```

- [ ] **Step 18: Thêm service vào `docker-compose.yml`**

Thêm sau khối `booking:`:

```yaml
  platform-deps:   # cài node_modules một lần vào volume dùng chung cho 4 app NestJS
    build: ./services/platform
    profiles: ["platform"]
    volumes:
      - ./services/platform:/app
      - platform-node-modules:/app/node_modules
    command: ["pnpm", "install", "--frozen-lockfile"]

  identity:
    build: ./services/platform
    profiles: ["platform"]
    environment: { APP: identity, PORT: "3000" }
    volumes:
      - ./services/platform:/app
      - platform-node-modules:/app/node_modules
    depends_on:
      platform-deps: { condition: service_completed_successfully }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.identity.rule=Path(`/identity`) || PathPrefix(`/identity/`)"
      - "traefik.http.routers.identity.middlewares=identity-strip"
      - "traefik.http.middlewares.identity-strip.stripprefix.prefixes=/identity"
      - "traefik.http.services.identity.loadbalancer.server.port=3000"

  authz:
    build: ./services/platform
    profiles: ["platform"]
    environment: { APP: authz, PORT: "3000" }
    volumes:
      - ./services/platform:/app
      - platform-node-modules:/app/node_modules
    depends_on:
      platform-deps: { condition: service_completed_successfully }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authz.rule=Path(`/authz`) || PathPrefix(`/authz/`)"
      - "traefik.http.routers.authz.middlewares=authz-strip"
      - "traefik.http.middlewares.authz-strip.stripprefix.prefixes=/authz"
      - "traefik.http.services.authz.loadbalancer.server.port=3000"

  notification:
    build: ./services/platform
    profiles: ["platform"]
    environment: { APP: notification, PORT: "3000" }
    volumes:
      - ./services/platform:/app
      - platform-node-modules:/app/node_modules
    depends_on:
      platform-deps: { condition: service_completed_successfully }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.notification.rule=Path(`/notification`) || PathPrefix(`/notification/`)"
      - "traefik.http.routers.notification.middlewares=notification-strip"
      - "traefik.http.middlewares.notification-strip.stripprefix.prefixes=/notification"
      - "traefik.http.services.notification.loadbalancer.server.port=3000"

  storage:
    build: ./services/platform
    profiles: ["platform"]
    environment: { APP: storage, PORT: "3000" }
    volumes:
      - ./services/platform:/app
      - platform-node-modules:/app/node_modules
    depends_on:
      platform-deps: { condition: service_completed_successfully }
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.storage.rule=Path(`/storage`) || PathPrefix(`/storage/`)"
      - "traefik.http.routers.storage.middlewares=storage-strip"
      - "traefik.http.middlewares.storage-strip.stripprefix.prefixes=/storage"
      - "traefik.http.services.storage.loadbalancer.server.port=3000"
```

Thêm `platform-node-modules:` vào khối `volumes:` cuối file.

- [ ] **Step 19: Chạy 4 app trong Docker và kiểm tra qua gateway**

```bash
cd /Users/ryantruong/Project/Orther/branchbook
docker compose --profile platform up -d --build
sleep 90
for s in identity authz notification storage; do curl -s http://localhost:8100/$s/health; echo; done
```

Expected (4 dòng):
```
{"status":"ok","service":"identity"}
{"status":"ok","service":"authz"}
{"status":"ok","service":"notification"}
{"status":"ok","service":"storage"}
```

Nếu dòng nào lỗi `404`/`502`, xem `docker compose logs <app>` — app có thể chưa compile xong, chờ thêm rồi thử lại.

- [ ] **Step 20: Commit**

Run: `git status --short | grep -E "node_modules|/dist/" || echo "sạch"`
Expected: `sạch` (không có node_modules hay dist bị đưa vào git).

```bash
git add services/platform docker-compose.yml
git commit -m "feat(platform): NestJS monorepo 4 app (identity, authz, notification, storage) có /health sau Traefik"
```

---

> **Đã chỉnh sau review Task 4 (2026-10-13):** Nest CLI 12 sinh **Vitest 4 + oxlint + ESM + rspack** (không phải Jest/eslint): e2e dùng `vitest.config.e2e.ts` có sẵn; script `typecheck` (`tsc -p tsconfig.json --noEmit`) vì rspack không kiểm kiểu; `tsconfig.json` dùng `include` thay cho solution-style; `ENV pnpm_config_store_dir` trong Dockerfile; compose gộp bằng anchor `x-platform`, một image `branchbook-platform-dev`; `build:all` = `nest build --all`; bỏ script `build`/`start`/`start:dev`. Xem commit sau `52eb8c1`.

---

### Task 5: Makefile mới và cặp khoá RSA dev

**Files:**
- Modify (ghi đè): `Makefile`
- Modify: `services/booking/Dockerfile` (thêm `openssl`)
- Modify: `services/booking/.gitignore` (thêm `/storage/keys`)

- [ ] **Step 1: Thêm `openssl` vào image booking**

Ghi đè `services/booking/Dockerfile`:

```dockerfile
# Image dev cho booking (Laravel 13 cần PHP >= 8.3)
FROM php:8.4-cli-alpine

# openssl: sinh cặp khoá RSA dev cho JWT (make keys)
RUN apk add --no-cache openssl \
 && docker-php-ext-install pdo_mysql pcntl

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
EXPOSE 8000
# --no-reload: bắt buộc để artisan serve dùng PHP_CLI_SERVER_WORKERS (đổi .env thì restart container)
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000", "--no-reload"]
```

- [ ] **Step 2: Không commit khoá dev**

```bash
printf '/storage/keys\n' >> services/booking/.gitignore
```

- [ ] **Step 2b: `init.sql` khai báo danh sách service một lần** (góp ý review Task 2)

Ghi đè `infra/postgres/init.sql`:

```sql
-- Mỗi service NestJS một user + database riêng (dev). Thu hồi CONNECT của PUBLIC
-- để service này không kết nối được vào database của service khác.
-- Idempotent: chạy lại an toàn (make pg-init). Thêm service mới: chỉ sửa danh sách ngay dưới đây.
CREATE TEMP TABLE svc (name text PRIMARY KEY);
INSERT INTO svc VALUES ('identity'), ('authz'), ('notification');

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', name, name)
FROM svc
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = svc.name)
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', d, svc.name)
FROM svc, unnest(ARRAY[svc.name, svc.name || '_testing']) AS d
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = d)
\gexec

SELECT format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', d)
FROM svc, unnest(ARRAY[svc.name, svc.name || '_testing']) AS d
\gexec
```

Kiểm tra: `make pg-init` chạy 2 lần đều thoát 0; xoá volume `branchbook_postgres-data` rồi `docker compose up -d postgres` → đủ 6 database, `authz` vẫn bị từ chối khi vào `identity`.

- [ ] **Step 3: Ghi đè `Makefile`**

```make
.PHONY: up up-all down ps logs sh artisan composer test test-platform fresh pint keys pg-init

up:        ## Hạ tầng + booking: MySQL, Redis, PostgreSQL, RabbitMQ, Mailpit, Traefik (gateway http://localhost:8100)
	docker compose up -d --build

up-all:    ## Thêm các service NestJS: identity, authz, notification, storage
	docker compose --profile platform up -d --build

down:      ## Dừng tất cả (kể cả service NestJS)
	docker compose --profile platform down

ps:
	docker compose --profile platform ps

logs:      ## make logs s=identity (mặc định booking)
	docker compose --profile platform logs -f $(or $(s),booking)

sh:        ## Mở shell trong container booking
	docker compose exec booking sh

artisan:   ## make artisan c="route:list"
	docker compose exec booking php artisan $(c)

composer:  ## make composer c="require vendor/package"
	docker compose exec booking composer $(c)

test:      ## Test booking (Pest). make test f="--filter=Booking"
	docker compose exec booking ./vendor/bin/pest $(f)

test-platform: ## Type-check + unit + e2e test các service NestJS (-l: không để Traefik coi container test là một bản identity)
	docker compose --profile platform run --rm -l traefik.enable=false identity sh -c "pnpm typecheck && pnpm test && pnpm test:e2e"

fresh:     ## Tạo lại database booking + seed
	docker compose exec booking php artisan migrate:fresh --seed

pg-init:   ## Chạy lại infra/postgres/init.sql (idempotent) — khi thêm service/DB mới vào volume đã có dữ liệu
	docker compose exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 < infra/postgres/init.sql

pint:      ## Format code booking theo chuẩn Laravel
	docker compose exec booking ./vendor/bin/pint

keys:      ## Sinh cặp khoá RSA dev (storage/keys của booking) để ký/kiểm JWT tuần 1 — không commit
	docker compose exec booking sh -c "mkdir -p storage/keys \
	  && openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out storage/keys/dev-private.pem \
	  && openssl pkey -in storage/keys/dev-private.pem -pubout -out storage/keys/dev-public.pem"
```

- [ ] **Step 4: Kiểm tra các target**

```bash
docker compose up -d --build booking
sleep 15
make keys
ls services/booking/storage/keys
git status --short services/booking/storage
make test
make test-platform
```

Expected: `dev-private.pem  dev-public.pem`; `git status` không in gì cho `storage/`; `make test` báo `2 passed`; `make test-platform` báo typecheck sạch và e2e `4 passed`.

- [ ] **Step 5: Commit**

```bash
git add Makefile services/booking/Dockerfile services/booking/.gitignore
git commit -m "chore(infra): Makefile cho kiến trúc nhiều service, make keys sinh khoá RSA dev"
```

---

### Task 6: CI GitHub Actions

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Viết workflow**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  booking:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.4
        env:
          MYSQL_DATABASE: branchbook_testing
          MYSQL_USER: branchbook
          MYSQL_PASSWORD: branchbook
          MYSQL_ROOT_PASSWORD: root
        ports: ["3306:3306"]
        options: >-
          --health-cmd="mysqladmin ping -h 127.0.0.1 -uroot -proot"
          --health-interval=5s
          --health-retries=20
    defaults:
      run:
        working-directory: services/booking
    env:
      DB_HOST: 127.0.0.1
      DB_PORT: 3306
      DB_USERNAME: branchbook
      DB_PASSWORD: branchbook
    steps:
      - uses: actions/checkout@v7
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: pdo_mysql
          coverage: none
      - name: Cài dependency
        run: composer install --no-interaction --prefer-dist --no-progress
      - name: Chuẩn bị .env
        run: cp .env.example .env && php artisan key:generate
      - name: Pest (MySQL thật)
        run: ./vendor/bin/pest

  platform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/platform
    steps:
      - uses: actions/checkout@v7
      - uses: pnpm/action-setup@v6
        with:
          package_json_file: services/platform/package.json
      - uses: actions/setup-node@v7
        with:
          node-version: 24
          cache: pnpm
          cache-dependency-path: services/platform/pnpm-lock.yaml
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm typecheck
      - run: pnpm build:all
      - run: pnpm test
      - run: pnpm test:e2e
```

- [ ] **Step 2: Commit và push**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: chạy Pest (booking) và build + test (platform) trên GitHub Actions"
git push
```

- [ ] **Step 3: Theo dõi CI tới khi xong**

```bash
gh run list --limit 1
gh run watch "$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')" --exit-status
```

Expected: cả 2 job `booking` và `platform` thành công. Nếu fail: `gh run view --log-failed`, sửa nguyên nhân, commit, push, theo dõi lại. Không báo xong khi CI chưa xanh.

---

### Task 7: Cập nhật README, CLAUDE.md, ghi chú storage trong spec và design

**Files:**
- Modify (ghi đè): `README.md`
- Modify (ghi đè): `CLAUDE.md`
- Modify: `docs/design.md` (mục 3)
- Modify: `docs/superpowers/specs/2026-10-13-branchbook-product-plan.html` (các chỗ nhắc MinIO)

- [ ] **Step 1: Ghi đè `README.md`**

````markdown
# BranchBook

SaaS đặt lịch cho chuỗi trung tâm nhiều chi nhánh (đa tenant): hội viên xem slot trống, đặt và huỷ lịch, nhận thông báo; quản lý chi nhánh xem lịch real-time; chủ chuỗi tự đăng ký và quản lý chi nhánh.

Dự án học theo lộ trình 10 tuần, xây theo kiến trúc **microservice ngay từ đầu**, tập trung vào: thiết kế hệ thống, chống đặt trùng khi nhiều request đồng thời, xác thực và phân quyền giữa các service, message broker (outbox/inbox), saga, testing, cloud.

**Định hướng sản phẩm:** làm như một SaaS thật — nhiều chuỗi trung tâm (tenant) dùng chung hệ thống, dữ liệu tách theo tenant, có landing page, tài khoản demo và bản deploy công khai. Khách hàng là giả lập; số liệu chỉ lấy từ đo đạc/load test thật.

- Thiết kế (nguồn quyết định kỹ thuật): [`docs/design.md`](docs/design.md)
- Kế hoạch sản phẩm: [`docs/superpowers/specs/2026-10-13-branchbook-product-plan.html`](docs/superpowers/specs/2026-10-13-branchbook-product-plan.html)

## Kiến trúc

```
                         Traefik (gateway)
        ┌──────────┬──────────┬───┴──────┬──────────────┬──────────┐
       web      identity     authz     booking      notification  storage
     Next.js     NestJS      NestJS    Laravel        NestJS       NestJS
               PostgreSQL  PostgreSQL MySQL+Redis   PostgreSQL   kho S3 (tuần 7)
                                          └── outbox ──▶ RabbitMQ ──▶ notification
```

| Thư mục | Nội dung |
|---|---|
| `services/booking/` | Laravel 13 / PHP 8.4 / Pest 5 — chuỗi, chi nhánh, phòng, slot, gói hội viên, đặt/huỷ |
| `services/platform/` | NestJS 12 monorepo (Vitest, oxlint, ESM) — `apps/{identity,authz,notification,storage}` |
| `gateway/` | Cấu hình Traefik |
| `infra/` | Script khởi tạo MySQL, PostgreSQL |

## Chạy local

Yêu cầu: Docker. Không cần cài PHP trên máy.

```bash
make up            # hạ tầng + booking → http://localhost:8180/up, gateway http://localhost:8100/booking/up
make up-all        # thêm identity, authz, notification, storage → http://localhost:8100/<service>/health
make test          # Pest của booking trên MySQL branchbook_testing
make test-platform # type-check + unit + e2e test các service NestJS
make keys          # sinh cặp khoá RSA dev để ký/kiểm JWT (tuần 1)
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
````

- [ ] **Step 2: Ghi đè `CLAUDE.md`**

```markdown
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
- `make up` · `make up-all` · `make test` · `make test-platform` · `make keys` · `make sh` · `make artisan c="..."` · `make composer c="..."` · `make fresh` · `make pint` · `make logs s=<service>`
- Booking trực tiếp http://localhost:8180 · Gateway http://localhost:8100/<service> (Traefik, dashboard 8101) · MySQL `127.0.0.1:13306` (branchbook/branchbook) · Redis `127.0.0.1:16379` · PostgreSQL `127.0.0.1:15432` · RabbitMQ `127.0.0.1:35672` (UI 35673) · Mailpit UI 18025
- Test booking chạy trên MySQL `branchbook_testing` (không dùng SQLite) để test được lock, unique, generated column. Test NestJS dùng database `<service>_testing` trên PostgreSQL.

## Quy ước

- Booking: Laravel 13, PHP 8.4, Pest 5. Platform: NestJS 12, pnpm, Vitest + oxlint (ESM, mặc định của NestJS 12), `pnpm typecheck` vì build rspack không kiểm kiểu; mỗi app một database + user PostgreSQL riêng, không truy vấn chéo.
- Xác thực: JWT RS256 do identity cấp; mỗi service tự kiểm bằng public key. Tuần 1 dùng cặp khoá dev (`make keys`, không commit).
- API prefix `/api/v1`; lỗi nghiệp vụ trả `{"error": {"code": "...", "message": "..."}}`; validation trả 422 mặc định của Laravel.
- Kho file S3-compatible chọn ở tuần 7 (MinIO đã ngừng phát hành image).
- Mỗi quyết định kiến trúc quan trọng → một ADR trong `docs/adr/`.
```

- [ ] **Step 3: Ghi chú storage trong `docs/design.md`**

Trong bảng mục 3, sửa dòng `| storage | NestJS + MinIO | Upload/download file qua presigned URL |` thành:

```markdown
| storage | NestJS + kho S3-compatible (chọn ở tuần 7) | Upload/download file qua presigned URL |
```

Sửa dòng hạ tầng dùng chung thành:

```markdown
- Hạ tầng dùng chung: 1 MySQL, 1 PostgreSQL (mỗi service có database + user riêng, không truy vấn chéo), 1 Redis (tách theo tiền tố khoá), RabbitMQ, kho S3-compatible (MinIO đã ngừng phát hành image từ 09/2026 — chọn RustFS/Garage/SeaweedFS ở tuần 7).
```

- [ ] **Step 4: Ghi chú storage trong spec HTML**

```bash
SPEC=docs/superpowers/specs/2026-10-13-branchbook-product-plan.html
sed -i '' 's/PostgreSQL     MinIO/PostgreSQL     kho S3/' "$SPEC"
sed -i '' 's|<td>NestJS + MinIO</td>|<td>NestJS + kho S3-compatible (chọn ở tuần 7)</td>|' "$SPEC"
sed -i '' 's/RabbitMQ, MinIO, Mailpit (dev)\./RabbitMQ, Mailpit (dev); kho S3-compatible chọn ở tuần 7 vì MinIO đã ngừng phát hành image (09\/2026)./' "$SPEC"
sed -i '' 's/storage (MinIO, presigned URL)/storage (kho S3-compatible, presigned URL)/' "$SPEC"
sed -i '' 's/CI (Pest, Jest)/CI (Pest, Vitest)/' "$SPEC"
grep -n "MinIO" "$SPEC" docs/design.md
```

Expected: `grep` chỉ còn in các dòng ghi chú "MinIO đã ngừng phát hành image" (1 dòng trong spec, 1 dòng trong design.md).

- [ ] **Step 5: Commit và push**

```bash
git add README.md CLAUDE.md docs/design.md docs/superpowers/specs/2026-10-13-branchbook-product-plan.html
git commit -m "docs: README, CLAUDE.md theo kiến trúc microservice; ghi chú thay MinIO ở tuần 7"
git push
gh run watch "$(gh run list --limit 1 --json databaseId -q '.[0].databaseId')" --exit-status
```

Expected: CI xanh cả 2 job.
