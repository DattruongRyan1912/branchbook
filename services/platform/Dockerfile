# Image dev cho các app NestJS trong monorepo. Chọn app bằng biến APP (identity, authz, notification, storage).
FROM node:24-alpine

RUN npm install -g pnpm@11.5.2

WORKDIR /app
EXPOSE 3000
CMD ["sh", "-c", "pnpm nest start ${APP} --watch"]
