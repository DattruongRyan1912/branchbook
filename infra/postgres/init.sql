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

SELECT format('ALTER DATABASE %I OWNER TO %I', d, svc.name)
FROM svc, unnest(ARRAY[svc.name, svc.name || '_testing']) AS d
\gexec

SELECT format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', d)
FROM svc, unnest(ARRAY[svc.name, svc.name || '_testing']) AS d
\gexec
