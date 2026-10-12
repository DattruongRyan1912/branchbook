# Image dev cho booking (Laravel 13 cần PHP >= 8.3)
FROM php:8.4-cli-alpine

RUN docker-php-ext-install pdo_mysql pcntl

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
EXPOSE 8000
# --no-reload: bắt buộc để artisan serve dùng PHP_CLI_SERVER_WORKERS (đổi .env thì restart container)
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000", "--no-reload"]
