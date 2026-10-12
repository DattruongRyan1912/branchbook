-- Mỗi service NestJS một user + database riêng (dev). Thu hồi CONNECT của PUBLIC
-- để service này không kết nối được vào database của service khác.
-- Idempotent: chạy lại an toàn (make pg-init) khi thêm service vào volume đã có dữ liệu.
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', s, s)
FROM unnest(ARRAY['identity', 'authz', 'notification']) AS s
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = s)
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', d, s)
FROM unnest(ARRAY['identity', 'authz', 'notification']) AS s,
     unnest(ARRAY[s, s || '_testing']) AS d
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = d)
\gexec

SELECT format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', d)
FROM unnest(ARRAY['identity', 'authz', 'notification']) AS s,
     unnest(ARRAY[s, s || '_testing']) AS d
\gexec
