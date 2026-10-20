-- ---------- 1. Role ----------
CREATE ROLE IF NOT EXISTS r_reader, r_admin, r_manager, r_staff, r_driver;

-- ---------- 2. r_reader: đọc dữ liệu nghiệp vụ, KHÔNG đọc bảng employee ----------
GRANT SELECT ON cold_chain_db.warehouse             TO r_reader;
GRANT SELECT ON cold_chain_db.product               TO r_reader;
GRANT SELECT ON cold_chain_db.raw_material          TO r_reader;
GRANT SELECT ON cold_chain_db.finished_good         TO r_reader;
GRANT SELECT ON cold_chain_db.product_component     TO r_reader;
GRANT SELECT ON cold_chain_db.inventory             TO r_reader;
GRANT SELECT ON cold_chain_db.supplier              TO r_reader;
GRANT SELECT ON cold_chain_db.supplier_certificate  TO r_reader;
GRANT SELECT ON cold_chain_db.purchase_order        TO r_reader;
GRANT SELECT ON cold_chain_db.order_detail          TO r_reader;
GRANT SELECT ON cold_chain_db.vehicle               TO r_reader;
GRANT SELECT ON cold_chain_db.shipment              TO r_reader;
GRANT SELECT ON cold_chain_db.stock_movement        TO r_reader;
GRANT SELECT ON cold_chain_db.inventory_alert       TO r_reader;
GRANT SELECT ON cold_chain_db.audit_log             TO r_reader;
GRANT SELECT ON cold_chain_db.v_bom_current         TO r_reader;
GRANT SELECT ON cold_chain_db.v_low_stock           TO r_reader;
GRANT SELECT ON cold_chain_db.v_warehouse_utilization TO r_reader;
GRANT SELECT ON cold_chain_db.v_receipt_traceability  TO r_reader;
GRANT SELECT ON cold_chain_db.v_product_missing_subtype TO r_reader;
GRANT SELECT ON cold_chain_db.v_employee_public     TO r_reader;
GRANT SELECT ON cold_chain_db.v_my_inventory        TO r_reader;
GRANT SELECT ON cold_chain_db.v_my_shipments        TO r_reader;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_trace_finished_good TO r_reader;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_bind_actor          TO r_reader;

-- ---------- 3. Admin ----------
GRANT r_reader TO r_admin;
GRANT SELECT  ON cold_chain_db.employee              TO r_admin;
GRANT SELECT  ON cold_chain_db.v_employee_directory  TO r_admin;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_confirm_purchase_order TO r_admin;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_cancel_purchase_order  TO r_admin;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_add_employee           TO r_admin;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_get_employee_phone     TO r_admin;

-- ---------- 4. Warehouse_Manager: xác nhận / hủy đơn ----------
GRANT r_reader TO r_manager;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_confirm_purchase_order TO r_manager;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_cancel_purchase_order  TO r_manager;

-- ---------- 5. Warehouse_Staff: tạo đơn, tạo chuyến, nhận hàng, lập phiếu kho ----------
GRANT r_reader TO r_staff;
GRANT INSERT  ON cold_chain_db.purchase_order TO r_staff;
GRANT INSERT  ON cold_chain_db.order_detail   TO r_staff;
GRANT INSERT  ON cold_chain_db.shipment       TO r_staff;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_receive_purchase_order TO r_staff;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_record_stock_movement  TO r_staff;

-- ---------- 6. Driver: chỉ thấy chuyến của mình và chỉ ghi nhiệt độ ----------
GRANT SELECT  ON cold_chain_db.v_my_shipments TO r_driver;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_bind_actor         TO r_driver;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_start_shipment     TO r_driver;
GRANT EXECUTE ON PROCEDURE cold_chain_db.sp_complete_shipment  TO r_driver;

-- ---------- 7. Tài khoản mẫu (mã nhân viên trong dữ liệu mẫu) ----------
CREATE USER IF NOT EXISTS 'EMP-000001'@'localhost' IDENTIFIED BY 'Demo#Admin2026';
CREATE USER IF NOT EXISTS 'EMP-000011'@'localhost' IDENTIFIED BY 'Demo#Mgr2026';
CREATE USER IF NOT EXISTS 'EMP-000021'@'localhost' IDENTIFIED BY 'Demo#Staff2026';
CREATE USER IF NOT EXISTS 'EMP-000042'@'localhost' IDENTIFIED BY 'Demo#Drv2026';
CREATE USER IF NOT EXISTS 'EMP-000045'@'localhost' IDENTIFIED BY 'Demo#Left2026';

GRANT r_admin   TO 'EMP-000001'@'localhost';
GRANT r_manager TO 'EMP-000011'@'localhost';
GRANT r_staff   TO 'EMP-000021'@'localhost';
GRANT r_driver  TO 'EMP-000042'@'localhost';
GRANT r_driver  TO 'EMP-000045'@'localhost';

SET DEFAULT ROLE r_admin   TO 'EMP-000001'@'localhost';
SET DEFAULT ROLE r_manager TO 'EMP-000011'@'localhost';
SET DEFAULT ROLE r_staff   TO 'EMP-000021'@'localhost';
SET DEFAULT ROLE r_driver  TO 'EMP-000042'@'localhost';

-- ---------- 8. REVOKE ----------
-- 8a. EMP-000045 đã nghỉ việc (BR-EMP-03): thu hồi role và khóa tài khoản.
REVOKE r_driver FROM 'EMP-000045'@'localhost';
ALTER USER 'EMP-000045'@'localhost' ACCOUNT LOCK;

-- 8b. Kiểm thử thu hồi quyền: cấp tạm rồi thu hồi quyền giải mã danh bạ của Manager.
GRANT  SELECT ON cold_chain_db.v_employee_directory TO r_manager;
REVOKE SELECT ON cold_chain_db.v_employee_directory FROM r_manager;

-- ---------- 9. Kiểm tra ----------
SHOW GRANTS FOR r_staff;
SHOW GRANTS FOR 'EMP-000021'@'localhost' USING r_staff;