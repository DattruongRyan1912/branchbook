.PHONY: up down sh artisan composer test fresh logs pint

up:        ## Khởi động mysql, redis, booking (http://localhost:8180)
	docker compose up -d --build

down:
	docker compose down

sh:        ## Mở shell trong container booking
	docker compose exec booking sh

artisan:   ## make artisan c="route:list"
	docker compose exec booking php artisan $(c)

composer:  ## make composer c="require vendor/package"
	docker compose exec booking composer $(c)

test:      ## make test f="--filter=Booking"
	docker compose exec booking ./vendor/bin/pest $(f)

fresh:     ## Tạo lại database + seed dữ liệu mẫu
	docker compose exec booking php artisan migrate:fresh --seed

pint:      ## Format code theo chuẩn Laravel
	docker compose exec booking ./vendor/bin/pint

logs:
	docker compose logs -f booking
