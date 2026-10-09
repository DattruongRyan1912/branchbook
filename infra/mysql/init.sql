-- Database riêng cho test (Pest chạy trên MySQL thật để test được lock, unique, generated column)
CREATE DATABASE IF NOT EXISTS branchbook_testing;
GRANT ALL PRIVILEGES ON branchbook_testing.* TO 'branchbook'@'%';
FLUSH PRIVILEGES;
