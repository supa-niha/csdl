CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED BY 'ChangeMe#2026';
 
GRANT SELECT  ON cold_chain_db.*               TO 'app_user'@'localhost';
GRANT EXECUTE ON cold_chain_db.*               TO 'app_user'@'localhost';
GRANT INSERT  ON cold_chain_db.purchase_order  TO 'app_user'@'localhost';
GRANT INSERT  ON cold_chain_db.order_detail    TO 'app_user'@'localhost';
GRANT INSERT  ON cold_chain_db.shipment        TO 'app_user'@'localhost';
 
-- Sinh mã PO-/SHP- dùng SELECT MAX(...) ... FOR UPDATE. MySQL yêu cầu SELECT cộng ít nhất một trong
-- UPDATE / DELETE / LOCK TABLES cho câu khóa dòng này; chọn LOCK TABLES để KHÔNG cấp quyền sửa dữ liệu.
GRANT LOCK TABLES ON cold_chain_db.*           TO 'app_user'@'localhost';
 
FLUSH PRIVILEGES;