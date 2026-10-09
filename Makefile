.PHONY: up down sh artisan composer test fresh logs pint

up:        ## Khởi động mysql, redis, core-api (http://localhost:8180)
	docker compose up -d --build

down:
	docker compose down

sh:        ## Mở shell trong container core-api
	docker compose exec core-api sh

artisan:   ## make artisan c="route:list"
	docker compose exec core-api php artisan $(c)

composer:  ## make composer c="require vendor/package"
	docker compose exec core-api composer $(c)

test:      ## make test f="--filter=Booking"
	docker compose exec core-api ./vendor/bin/pest $(f)

fresh:     ## Tạo lại database + seed dữ liệu mẫu
	docker compose exec core-api php artisan migrate:fresh --seed

pint:      ## Format code theo chuẩn Laravel
	docker compose exec core-api ./vendor/bin/pint

logs:
	docker compose logs -f core-api
