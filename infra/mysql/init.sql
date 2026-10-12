-- Database riêng cho test (Pest chạy trên MySQL thật để test được lock, unique, generated column).
-- Quyền theo mẫu branchbook\_testing% để `pest --parallel` tự tạo được branchbook_testing_test_N
-- (\_ là dấu gạch dưới thật, % khớp mọi hậu tố, kể cả rỗng).
CREATE DATABASE IF NOT EXISTS branchbook_testing;
GRANT ALL PRIVILEGES ON `branchbook\_testing%`.* TO 'branchbook'@'%';
FLUSH PRIVILEGES;
