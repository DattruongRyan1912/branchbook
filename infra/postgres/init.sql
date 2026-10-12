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
