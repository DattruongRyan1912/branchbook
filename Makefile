.PHONY: help up up-all down ps logs sh artisan composer test test-platform fresh pint keys pg-init

help:      ## Liệt kê các lệnh
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-14s %s\n", $$1, $$2}'

up:        ## Hạ tầng + booking: MySQL, Redis, PostgreSQL, RabbitMQ, Mailpit, Traefik (gateway http://localhost:8100)
	docker compose up -d --build

up-all:    ## Thêm các service NestJS: identity, authz, notification, storage
	docker compose --profile platform up -d --build

down:      ## Dừng tất cả (kể cả service NestJS)
	docker compose --profile platform down

ps:        ## Trạng thái các container
	docker compose --profile platform ps

logs:      ## make logs s=identity (mặc định booking)
	docker compose --profile platform logs -f --tail=100 $(or $(s),booking)

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

keys:      ## Sinh cặp khoá RSA dev (storage/keys của booking) để ký/kiểm JWT tuần 1 — không commit; đã có thì giữ nguyên (muốn sinh lại: xoá services/booking/storage/keys)
	docker compose exec booking sh -c "mkdir -p storage/keys \
	  && { [ -f storage/keys/dev-private.pem ] || openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out storage/keys/dev-private.pem; } \
	  && openssl pkey -in storage/keys/dev-private.pem -pubout -out storage/keys/dev-public.pem"
