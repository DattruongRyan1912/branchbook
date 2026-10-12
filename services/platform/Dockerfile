# Image dev cho các app NestJS trong monorepo. Chọn app bằng biến APP (identity, authz, notification, storage).
FROM node:24-alpine

# cập nhật cùng lúc với "packageManager" trong package.json
RUN npm install -g pnpm@11.5.2

# Store pnpm nằm trong volume node_modules: không ghi .pnpm-store ra thư mục host (bind mount).
# pnpm 11 đọc biến pnpm_config_*, không đọc npm_config_*.
ENV pnpm_config_store_dir=/app/node_modules/.pnpm-store

WORKDIR /app
EXPOSE 3000
CMD ["sh", "-c", "pnpm nest start ${APP} --watch"]
