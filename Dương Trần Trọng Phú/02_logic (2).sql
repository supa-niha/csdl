-- =====================================================================
-- Project : INT1313 - Supply Chain & Warehouse Logistics Network
-- Team    : Eternal
-- File    : 02_logic.sql
-- Run AFTER: 01_schema.sql
-- Database: cold_chain_db
-- Re-runnable: drops existing routines/triggers/views first
-- =====================================================================
USE cold_chain_db;
SET NAMES utf8mb4;
SET SESSION block_encryption_mode = 'aes-256-cbc';

-- ----- Clean previous logic objects (safe re-run) -----
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS v_my_shipments;
DROP VIEW IF EXISTS v_my_inventory;
DROP VIEW IF EXISTS v_employee_public;
DROP VIEW IF EXISTS v_employee_directory;
DROP VIEW IF EXISTS v_product_missing_subtype;
DROP VIEW IF EXISTS v_receipt_traceability;
DROP VIEW IF EXISTS v_warehouse_utilization;
DROP VIEW IF EXISTS v_low_stock;
DROP VIEW IF EXISTS v_bom_current;

DROP TRIGGER IF EXISTS trg_shipment_au;
DROP TRIGGER IF EXISTS trg_shipment_ai;
DROP TRIGGER IF EXISTS trg_shipment_bd;
DROP TRIGGER IF EXISTS trg_shipment_bu;
DROP TRIGGER IF EXISTS trg_shipment_bi;
DROP TRIGGER IF EXISTS trg_order_detail_ad;
DROP TRIGGER IF EXISTS trg_order_detail_au;
DROP TRIGGER IF EXISTS trg_order_detail_ai;
DROP TRIGGER IF EXISTS trg_order_detail_bd;
DROP TRIGGER IF EXISTS trg_order_detail_bu;
DROP TRIGGER IF EXISTS trg_order_detail_bi;
DROP TRIGGER IF EXISTS trg_purchase_order_au;
DROP TRIGGER IF EXISTS trg_purchase_order_ai;
DROP TRIGGER IF EXISTS trg_purchase_order_bd;
DROP TRIGGER IF EXISTS trg_purchase_order_bu;
DROP TRIGGER IF EXISTS trg_purchase_order_bi;
DROP TRIGGER IF EXISTS trg_audit_log_bd;
DROP TRIGGER IF EXISTS trg_audit_log_bu;
DROP TRIGGER IF EXISTS trg_stock_movement_bd;
DROP TRIGGER IF EXISTS trg_stock_movement_bu;
DROP TRIGGER IF EXISTS trg_stock_movement_ai;
DROP TRIGGER IF EXISTS trg_stock_movement_bi;
DROP TRIGGER IF EXISTS trg_inventory_au;
DROP TRIGGER IF EXISTS trg_inventory_ai;
DROP TRIGGER IF EXISTS trg_inventory_bu;
DROP TRIGGER IF EXISTS trg_inventory_bi;
DROP TRIGGER IF EXISTS trg_product_component_bd;
DROP TRIGGER IF EXISTS trg_product_component_bu;
DROP TRIGGER IF EXISTS trg_product_component_bi;
DROP TRIGGER IF EXISTS trg_finished_good_bu;
DROP TRIGGER IF EXISTS trg_finished_good_bi;
DROP TRIGGER IF EXISTS trg_raw_material_bu;
DROP TRIGGER IF EXISTS trg_raw_material_bi;
DROP TRIGGER IF EXISTS trg_product_bu;
DROP TRIGGER IF EXISTS trg_product_bi;
DROP TRIGGER IF EXISTS trg_warehouse_bu;

DROP PROCEDURE IF EXISTS sp_get_employee_phone;
DROP PROCEDURE IF EXISTS sp_add_employee;
DROP PROCEDURE IF EXISTS sp_trace_finished_good;
DROP PROCEDURE IF EXISTS sp_record_stock_movement;
DROP PROCEDURE IF EXISTS sp_complete_shipment;
DROP PROCEDURE IF EXISTS sp_start_shipment;
DROP PROCEDURE IF EXISTS sp_receive_purchase_order;
DROP PROCEDURE IF EXISTS sp_cancel_purchase_order;
DROP PROCEDURE IF EXISTS sp_confirm_purchase_order;
DROP PROCEDURE IF EXISTS sp_change_po_status;
DROP PROCEDURE IF EXISTS sp_bind_actor;
DROP PROCEDURE IF EXISTS sp_assert_product_type;
DROP PROCEDURE IF EXISTS sp_refresh_inventory_alert;

DROP FUNCTION IF EXISTS fn_cold_chain_ceiling;
DROP FUNCTION IF EXISTS fn_warehouse_used_volume;
DROP FUNCTION IF EXISTS fn_is_storage_compatible;
DROP FUNCTION IF EXISTS fn_actor_warehouse;
DROP FUNCTION IF EXISTS fn_actor_role;
DROP FUNCTION IF EXISTS fn_decrypt_phone;
DROP FUNCTION IF EXISTS fn_encrypt_phone;

SET FOREIGN_KEY_CHECKS = 1;


DELIMITER $$

-- ---------------------------------------------------------------------
-- A. Hàm tiện ích
-- ---------------------------------------------------------------------

-- Mã hóa số điện thoại bằng AES-256-CBC, IV ngẫu nhiên 16 byte nối đầu bản mã (NFR-04).
-- Yêu cầu: SET SESSION block_encryption_mode = 'aes-256-cbc'; SET @app_key = '<khóa>';
CREATE FUNCTION fn_encrypt_phone(p_phone VARCHAR(15))
RETURNS VARBINARY(64)
NOT DETERMINISTIC NO SQL
BEGIN
    DECLARE v_iv VARBINARY(16);
    SET v_iv = RANDOM_BYTES(16);
    RETURN CONCAT(v_iv, AES_ENCRYPT(p_phone, @app_key, v_iv));
END$$

CREATE FUNCTION fn_decrypt_phone(p_cipher VARBINARY(64))
RETURNS VARCHAR(15) CHARSET utf8mb4
NOT DETERMINISTIC NO SQL
BEGIN
    RETURN CONVERT(
        AES_DECRYPT(SUBSTRING(p_cipher, 17), @app_key, SUBSTRING(p_cipher, 1, 16))
        USING utf8mb4);
END$$

-- Vai trò / kho của người đang thao tác (biến phiên @current_employee_id, BR-AUD-03).
-- Trả về NULL nếu chưa gán hoặc nhân viên đã nghỉ việc (BR-EMP-03).
CREATE FUNCTION fn_actor_role()
RETURNS VARCHAR(30) CHARSET utf8mb4
NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT e.role FROM employee e
             WHERE e.employee_id = @current_employee_id AND e.is_active = TRUE);
END$$

CREATE FUNCTION fn_actor_warehouse()
RETURNS VARCHAR(10) CHARSET utf8mb4
NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT e.warehouse_id FROM employee e
             WHERE e.employee_id = @current_employee_id AND e.is_active = TRUE);
END$$

-- Loại bảo quản của mặt hàng có hợp với loại kho không (BR-WH-08)
CREATE FUNCTION fn_is_storage_compatible(p_warehouse_id VARCHAR(10), p_product_id VARCHAR(10))
RETURNS TINYINT(1)
NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN EXISTS (
        SELECT 1
          FROM warehouse w
          JOIN product p ON p.product_id = p_product_id
         WHERE w.warehouse_id = p_warehouse_id
           AND ((w.warehouse_type = 'Cold'   AND p.storage_type = 'Chilled')
             OR (w.warehouse_type = 'Frozen' AND p.storage_type = 'Frozen')));
END$$

-- Thể tích đang chiếm của kho (loại trừ một mặt hàng nếu truyền vào) - BR-WH-07
CREATE FUNCTION fn_warehouse_used_volume(p_warehouse_id VARCHAR(10), p_exclude_product VARCHAR(10))
RETURNS DECIMAL(18,6)
NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT COALESCE(SUM(i.quantity * p.volume_m3), 0)
              FROM inventory i
              JOIN product p ON p.product_id = i.product_id
             WHERE i.warehouse_id = p_warehouse_id
               AND (p_exclude_product IS NULL OR i.product_id <> p_exclude_product));
END$$

-- Ngưỡng trần nhiệt độ của một đơn hàng (BR-SHP-08):
-- LEAST(MIN(required_temp) + 2.0 ; 4.0 với kho Cold hoặc -18.0 với kho Frozen)
CREATE FUNCTION fn_cold_chain_ceiling(p_po_id VARCHAR(15))
RETURNS DECIMAL(5,1)
NOT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT LEAST(MIN(od.required_temp) + 2.0,
                         CASE w.warehouse_type WHEN 'Cold' THEN 4.0 ELSE -18.0 END)
              FROM purchase_order po
              JOIN warehouse w     ON w.warehouse_id = po.warehouse_id
              JOIN order_detail od ON od.po_id = po.po_id
             WHERE po.po_id = p_po_id
             GROUP BY w.warehouse_type);
END$$

-- ---------------------------------------------------------------------
-- B. Procedure dùng nội bộ bởi trigger
-- ---------------------------------------------------------------------

-- Mở / đóng cảnh báo tồn kho thấp (BR-ALT-02, BR-ALT-04)
CREATE PROCEDURE sp_refresh_inventory_alert(
    IN p_warehouse_id VARCHAR(10), IN p_product_id VARCHAR(10),
    IN p_quantity DECIMAL(12,3),   IN p_reorder_level DECIMAL(12,3))
BEGIN
    IF p_quantity <= p_reorder_level THEN
        IF NOT EXISTS (SELECT 1 FROM inventory_alert
                        WHERE warehouse_id = p_warehouse_id
                          AND product_id = p_product_id AND status = 'Open') THEN
            INSERT INTO inventory_alert
                (warehouse_id, product_id, quantity_at_alert, reorder_level_at_alert,
                 status, created_at)
            VALUES (p_warehouse_id, p_product_id, p_quantity, p_reorder_level,
                    'Open', NOW());
        END IF;
    ELSE
        UPDATE inventory_alert
           SET status = 'Resolved', resolved_at = NOW()
         WHERE warehouse_id = p_warehouse_id
           AND product_id = p_product_id AND status = 'Open';
    END IF;
END$$

-- Kiểm tra mặt hàng thuộc đúng lớp con (chuyên biệt hóa disjoint - BR-PR-02)
CREATE PROCEDURE sp_assert_product_type(IN p_product_id VARCHAR(10), IN p_expected VARCHAR(20))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM product
                    WHERE product_id = p_product_id AND product_type = p_expected) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PR-02] Loại mặt hàng không khớp với bảng con (RAW_MATERIAL/FINISHED_GOOD).';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C. Trigger: WAREHOUSE
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_warehouse_bu BEFORE UPDATE ON warehouse
FOR EACH ROW
BEGIN
    IF NEW.warehouse_type <> OLD.warehouse_type
       AND EXISTS (SELECT 1 FROM inventory WHERE warehouse_id = OLD.warehouse_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-WH-08] Không được đổi loại kho khi kho còn bản ghi tồn kho.';
    END IF;
    IF NEW.capacity_m3 < OLD.capacity_m3
       AND fn_warehouse_used_volume(OLD.warehouse_id, NULL) > NEW.capacity_m3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-WH-07] Sức chứa mới nhỏ hơn thể tích hàng đang lưu trong kho.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- D. Trigger: PRODUCT và hai lớp con
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_product_bi BEFORE INSERT ON product
FOR EACH ROW
BEGIN
    IF NEW.unit = '' THEN                                   -- BR-PR-05: đơn vị mặc định theo loại
        SET NEW.unit = IF(NEW.product_type = 'RAW_MATERIAL', 'kg', 'box');
    END IF;
    IF NEW.product_type = 'FINISHED_GOOD' AND NEW.status = 'Active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-02] Thành phẩm phải có định mức rồi mới được chuyển sang Active.';
    END IF;
END$$

CREATE TRIGGER trg_product_bu BEFORE UPDATE ON product
FOR EACH ROW
BEGIN
    IF NEW.product_type <> OLD.product_type THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PR-02] Không được đổi loại RAW_MATERIAL / FINISHED_GOOD của mặt hàng.';
    END IF;
    IF NEW.storage_type <> OLD.storage_type
       AND (EXISTS (SELECT 1 FROM inventory WHERE product_id = OLD.product_id)
         OR EXISTS (SELECT 1 FROM order_detail WHERE product_id = OLD.product_id)
         OR EXISTS (SELECT 1 FROM product_component
                     WHERE parent_product_id = OLD.product_id
                        OR component_product_id = OLD.product_id)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-WH-08] Không đổi loại bảo quản khi mặt hàng đã có tồn kho, đơn hàng hoặc định mức.';
    END IF;
    IF NEW.product_type = 'FINISHED_GOOD' AND NEW.status = 'Active' AND OLD.status <> 'Active'
       AND NOT EXISTS (SELECT 1 FROM product_component
                        WHERE parent_product_id = OLD.product_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-02] Thành phẩm Active phải có ít nhất một thành phần trong định mức.';
    END IF;
END$$

CREATE TRIGGER trg_raw_material_bi BEFORE INSERT ON raw_material
FOR EACH ROW
BEGIN
    CALL sp_assert_product_type(NEW.product_id, 'RAW_MATERIAL');
END$$

CREATE TRIGGER trg_raw_material_bu BEFORE UPDATE ON raw_material
FOR EACH ROW
BEGIN
    CALL sp_assert_product_type(NEW.product_id, 'RAW_MATERIAL');
END$$

CREATE TRIGGER trg_finished_good_bi BEFORE INSERT ON finished_good
FOR EACH ROW
BEGIN
    CALL sp_assert_product_type(NEW.product_id, 'FINISHED_GOOD');
END$$

CREATE TRIGGER trg_finished_good_bu BEFORE UPDATE ON finished_good
FOR EACH ROW
BEGIN
    CALL sp_assert_product_type(NEW.product_id, 'FINISHED_GOOD');
END$$

-- ---------------------------------------------------------------------
-- E. Trigger: PRODUCT_COMPONENT (Bill of Materials)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_product_component_bi BEFORE INSERT ON product_component
FOR EACH ROW
BEGIN
    DECLARE v_parent_type  VARCHAR(20);
    DECLARE v_parent_stat  VARCHAR(20);
    DECLARE v_parent_stor  VARCHAR(20);
    DECLARE v_comp_stat    VARCHAR(20);
    DECLARE v_comp_stor    VARCHAR(20);
    DECLARE v_cycle        INT DEFAULT 0;

    IF NEW.parent_product_id = NEW.component_product_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-04] Một mặt hàng không thể là thành phần của chính nó.';
    END IF;

    SET v_parent_type = (SELECT product_type FROM product WHERE product_id = NEW.parent_product_id);
    SET v_parent_stat = (SELECT status       FROM product WHERE product_id = NEW.parent_product_id);
    SET v_parent_stor = (SELECT storage_type FROM product WHERE product_id = NEW.parent_product_id);
    SET v_comp_stat   = (SELECT status       FROM product WHERE product_id = NEW.component_product_id);
    SET v_comp_stor   = (SELECT storage_type FROM product WHERE product_id = NEW.component_product_id);

    IF v_parent_type <> 'FINISHED_GOOD' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-02] Mặt hàng cha của định mức phải là thành phẩm (FINISHED_GOOD).';
    END IF;
    IF v_parent_stat IN ('Discontinued', 'Archived') OR v_comp_stat IN ('Discontinued', 'Archived') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PR-09] Mặt hàng Discontinued/Archived không được đưa vào định mức mới.';
    END IF;
    IF v_parent_stor = 'Chilled' AND v_comp_stor = 'Frozen' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-09] Thành phần Frozen không tương thích với thành phẩm cha Chilled.';
    END IF;

    -- BR-BOM-05: chặn vòng lặp nhiều cấp (cha có đi tới được từ thành phần mới không?)
    WITH RECURSIVE sub (pid) AS (
        SELECT NEW.component_product_id
        UNION
        SELECT pc.component_product_id
          FROM product_component pc
          JOIN sub ON pc.parent_product_id = sub.pid
    )
    SELECT COUNT(*) INTO v_cycle FROM sub WHERE pid = NEW.parent_product_id;
    IF v_cycle > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-05] Định mức tạo vòng lặp: thành phần đã (gián tiếp) chứa thành phẩm cha.';
    END IF;
END$$

CREATE TRIGGER trg_product_component_bu BEFORE UPDATE ON product_component
FOR EACH ROW
BEGIN
    IF NEW.parent_product_id <> OLD.parent_product_id
       OR NEW.component_product_id <> OLD.component_product_id
       OR NEW.effective_date <> OLD.effective_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-01] Không sửa khóa định mức; hãy thêm phiên bản mới với effective_date mới.';
    END IF;
    IF (SELECT status FROM product WHERE product_id = OLD.parent_product_id) = 'Active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-08] Thành phẩm Active: không sửa dòng cũ, hãy tạo phiên bản định mức mới.';
    END IF;
END$$

CREATE TRIGGER trg_product_component_bd BEFORE DELETE ON product_component
FOR EACH ROW
BEGIN
    IF (SELECT status FROM product WHERE product_id = OLD.parent_product_id) = 'Active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-BOM-08] Thành phẩm Active: không xóa dòng định mức, hãy tạo phiên bản mới.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- F. Trigger: INVENTORY
--    INVENTORY.quantity chỉ đổi khi stock_movement bật cờ @inv_via_movement (BR-INV-05)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_inventory_bi BEFORE INSERT ON inventory
FOR EACH ROW
BEGIN
    DECLARE v_active    TINYINT;
    DECLARE v_capacity  DECIMAL(12,2);
    DECLARE v_volume    DECIMAL(10,3);

    IF NEW.quantity <> 0 AND IFNULL(@inv_via_movement, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-INV-05] Tồn kho chỉ được thay đổi qua phiếu biến động kho (STOCK_MOVEMENT).';
    END IF;
    IF NOT fn_is_storage_compatible(NEW.warehouse_id, NEW.product_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-INV-09] Loại bảo quản của mặt hàng không tương thích với loại kho.';
    END IF;
    IF NEW.quantity > 0 THEN
        SET v_active   = (SELECT is_active   FROM warehouse WHERE warehouse_id = NEW.warehouse_id);
        SET v_capacity = (SELECT capacity_m3 FROM warehouse WHERE warehouse_id = NEW.warehouse_id);
        SET v_volume   = (SELECT volume_m3   FROM product   WHERE product_id   = NEW.product_id);
        IF v_active = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-INV-10] Kho đã ngừng hoạt động không được tăng tồn kho.';
        END IF;
        IF fn_warehouse_used_volume(NEW.warehouse_id, NEW.product_id)
           + NEW.quantity * v_volume > v_capacity THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-WH-07] Tổng thể tích hàng vượt quá sức chứa (capacity_m3) của kho.';
        END IF;
    END IF;
    SET NEW.last_updated = NOW();
END$$

CREATE TRIGGER trg_inventory_bu BEFORE UPDATE ON inventory
FOR EACH ROW
BEGIN
    DECLARE v_active    TINYINT;
    DECLARE v_capacity  DECIMAL(12,2);
    DECLARE v_volume    DECIMAL(10,3);

    IF NEW.warehouse_id <> OLD.warehouse_id OR NEW.product_id <> OLD.product_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-INV-01] Không được sửa khóa (warehouse_id, product_id) của bản ghi tồn kho.';
    END IF;
    IF NEW.quantity <> OLD.quantity THEN
        IF IFNULL(@inv_via_movement, 0) <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-INV-05] Tồn kho chỉ được thay đổi qua phiếu biến động kho (STOCK_MOVEMENT).';
        END IF;
        SET NEW.last_updated = NOW();
        IF NEW.quantity > OLD.quantity THEN
            SET v_active   = (SELECT is_active   FROM warehouse WHERE warehouse_id = NEW.warehouse_id);
            SET v_capacity = (SELECT capacity_m3 FROM warehouse WHERE warehouse_id = NEW.warehouse_id);
            SET v_volume   = (SELECT volume_m3   FROM product   WHERE product_id   = NEW.product_id);
            IF v_active = 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-INV-10] Kho đã ngừng hoạt động không được tăng tồn kho.';
            END IF;
            IF fn_warehouse_used_volume(NEW.warehouse_id, NEW.product_id)
               + NEW.quantity * v_volume > v_capacity THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-WH-07] Tổng thể tích hàng vượt quá sức chứa (capacity_m3) của kho.';
            END IF;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_inventory_ai AFTER INSERT ON inventory
FOR EACH ROW
BEGIN
    CALL sp_refresh_inventory_alert(NEW.warehouse_id, NEW.product_id, NEW.quantity, NEW.reorder_level);
END$$

CREATE TRIGGER trg_inventory_au AFTER UPDATE ON inventory
FOR EACH ROW
BEGIN
    CALL sp_refresh_inventory_alert(NEW.warehouse_id, NEW.product_id, NEW.quantity, NEW.reorder_level);
END$$

-- ---------------------------------------------------------------------
-- G. Trigger: STOCK_MOVEMENT (bất biến, cập nhật INVENTORY)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_stock_movement_bi BEFORE INSERT ON stock_movement
FOR EACH ROW
BEGIN
    DECLARE v_increase TINYINT;
    SET v_increase = NEW.movement_type IN ('Receipt', 'Production_In', 'Transfer_In', 'Adjust_In');

    IF NOT EXISTS (SELECT 1 FROM employee
                    WHERE employee_id = NEW.employee_id AND role = 'Warehouse_Staff'
                      AND is_active = TRUE AND warehouse_id = NEW.warehouse_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-STK-08] Người lập phiếu phải là Warehouse_Staff đang làm việc tại kho này.';
    END IF;

    IF NEW.movement_type = 'Receipt' THEN
        IF NOT EXISTS (SELECT 1 FROM purchase_order
                        WHERE po_id = NEW.po_id AND status = 'Received'
                          AND warehouse_id = NEW.warehouse_id) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-STK-05] Phiếu Receipt chỉ hợp lệ cho đơn đã Received và đúng kho nhận.';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM order_detail
                        WHERE po_id = NEW.po_id AND product_id = NEW.product_id) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-STK-05] Mặt hàng của phiếu Receipt không thuộc đơn đặt hàng.';
        END IF;
    END IF;

    IF v_increase = 1 THEN
        IF EXISTS (SELECT 1 FROM warehouse
                    WHERE warehouse_id = NEW.warehouse_id AND is_active = FALSE) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-WH-06] Kho đã ngừng hoạt động không được tăng tồn kho.';
        END IF;
        IF NOT fn_is_storage_compatible(NEW.warehouse_id, NEW.product_id) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-WH-08] Loại bảo quản của mặt hàng không tương thích với loại kho.';
        END IF;
    ELSEIF IFNULL((SELECT quantity FROM inventory
                    WHERE warehouse_id = NEW.warehouse_id AND product_id = NEW.product_id), 0)
           < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-INV-02] Không đủ tồn kho: giao dịch sẽ làm số lượng tồn kho âm.';
    END IF;
END$$

CREATE TRIGGER trg_stock_movement_ai AFTER INSERT ON stock_movement
FOR EACH ROW
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @inv_via_movement = 0;      -- không để cờ "mở khóa" tồn tại sau lỗi
        RESIGNAL;
    END;

    SET @inv_via_movement = 1;
    IF NEW.movement_type IN ('Receipt', 'Production_In', 'Transfer_In', 'Adjust_In') THEN
        IF EXISTS (SELECT 1 FROM inventory
                    WHERE warehouse_id = NEW.warehouse_id AND product_id = NEW.product_id) THEN
            UPDATE inventory
               SET quantity = quantity + NEW.quantity,
                   last_restock_date = IF(NEW.movement_type = 'Receipt',
                                          DATE(NEW.movement_time), last_restock_date)
             WHERE warehouse_id = NEW.warehouse_id AND product_id = NEW.product_id;
        ELSE
            INSERT INTO inventory
                (warehouse_id, product_id, quantity, reorder_level, last_restock_date)
            VALUES (NEW.warehouse_id, NEW.product_id, NEW.quantity, 0,
                    IF(NEW.movement_type = 'Receipt', DATE(NEW.movement_time), NULL));
        END IF;
    ELSE
        UPDATE inventory
           SET quantity = quantity - NEW.quantity
         WHERE warehouse_id = NEW.warehouse_id AND product_id = NEW.product_id;
    END IF;
    SET @inv_via_movement = 0;
END$$

CREATE TRIGGER trg_stock_movement_bu BEFORE UPDATE ON stock_movement
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '[BR-STK-07] Phiếu biến động kho là bất biến: hãy lập phiếu điều chỉnh.';
END$$

CREATE TRIGGER trg_stock_movement_bd BEFORE DELETE ON stock_movement
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '[BR-STK-07] Phiếu biến động kho là bất biến: không được xóa.';
END$$

-- ---------------------------------------------------------------------
-- H. Trigger: AUDIT_LOG (bất biến - BR-AUD-04)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_audit_log_bu BEFORE UPDATE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '[BR-AUD-04] Nhật ký kiểm toán là bất biến: không được sửa.';
END$$

CREATE TRIGGER trg_audit_log_bd BEFORE DELETE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '[BR-AUD-04] Nhật ký kiểm toán là bất biến: không được xóa.';
END$$

-- ---------------------------------------------------------------------
-- I. Trigger: PURCHASE_ORDER (máy trạng thái, phân quyền theo vai trò)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_purchase_order_bi BEFORE INSERT ON purchase_order
FOR EACH ROW
BEGIN
    IF NEW.status <> 'Draft' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-05] Đơn đặt hàng mới bắt buộc ở trạng thái Draft.';
    END IF;
    SET NEW.total_amount = 0;                                   -- BR-PO-13: do trigger tính
    IF EXISTS (SELECT 1 FROM supplier
                WHERE supplier_id = NEW.supplier_id AND is_active = FALSE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SUP-07] Nhà cung cấp đã ngừng hợp tác không được gán vào đơn mới.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM supplier_certificate
                    WHERE supplier_id = NEW.supplier_id
                      AND cert_expiry_date >= NEW.order_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SUP-06] Nhà cung cấp không có giấy chứng nhận còn hiệu lực tại ngày đặt hàng.';
    END IF;
    IF EXISTS (SELECT 1 FROM warehouse
                WHERE warehouse_id = NEW.warehouse_id AND is_active = FALSE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-08] Kho nhận hàng đã ngừng hoạt động.';
    END IF;
    IF EXISTS (SELECT 1 FROM employee
                WHERE employee_id = NEW.created_by AND is_active = FALSE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-EMP-03] Nhân viên đã nghỉ việc không được tạo đơn hàng.';
    END IF;
END$$

CREATE TRIGGER trg_purchase_order_bu BEFORE UPDATE ON purchase_order
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(30);

    IF OLD.status <> 'Draft'
       AND (NOT (NEW.supplier_id   <=> OLD.supplier_id)
         OR NOT (NEW.warehouse_id  <=> OLD.warehouse_id)
         OR NOT (NEW.created_by    <=> OLD.created_by)
         OR NOT (NEW.order_date    <=> OLD.order_date)
         OR NOT (NEW.expected_date <=> OLD.expected_date)
         OR NOT (NEW.total_amount  <=> OLD.total_amount)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-07] Chỉ được sửa nội dung đơn hàng khi đơn đang ở trạng thái Draft.';
    END IF;

    IF NEW.status <> OLD.status THEN
        IF NOT ((OLD.status = 'Draft'     AND NEW.status IN ('Confirmed', 'Cancelled'))
             OR (OLD.status = 'Confirmed' AND NEW.status IN ('Shipping', 'Cancelled'))
             OR (OLD.status = 'Shipping'  AND NEW.status IN ('Received', 'Cancelled'))) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-PO-05] Chuyển trạng thái đơn hàng không hợp lệ (không nhảy cóc, không quay ngược).';
        END IF;

        SET v_role = fn_actor_role();

        IF NEW.status = 'Confirmed' THEN
            IF v_role IS NULL OR v_role NOT IN ('Admin', 'Warehouse_Manager') THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-EMP-05] Chỉ Admin hoặc Warehouse_Manager được xác nhận (Confirmed) đơn hàng.';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM order_detail WHERE po_id = NEW.po_id) THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-PO-04] Đơn hàng phải có ít nhất một dòng chi tiết mới rời trạng thái Draft.';
            END IF;
        ELSEIF NEW.status = 'Shipping' THEN
            IF NOT EXISTS (SELECT 1 FROM shipment
                            WHERE po_id = NEW.po_id AND status IN ('In_Transit', 'Delivered')) THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-PO-14] Đơn chỉ sang Shipping khi có chuyến đầu tiên chuyển sang In_Transit.';
            END IF;
        ELSEIF NEW.status = 'Received' THEN
            IF v_role IS NULL OR v_role <> 'Warehouse_Staff'
               OR NOT (fn_actor_warehouse() <=> NEW.warehouse_id) THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-EMP-06] Chỉ Warehouse_Staff của đúng kho nhận mới được xác nhận Received.';
            END IF;
            IF EXISTS (SELECT 1 FROM shipment
                        WHERE po_id = NEW.po_id AND status IN ('Planned', 'In_Transit'))
               OR NOT EXISTS (SELECT 1 FROM shipment
                               WHERE po_id = NEW.po_id AND status = 'Delivered') THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-PO-10] Received cần ≥ 1 chuyến Delivered và không còn chuyến Planned/In_Transit.';
            END IF;
        ELSEIF NEW.status = 'Cancelled' THEN
            IF v_role IS NULL OR v_role NOT IN ('Admin', 'Warehouse_Manager') THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-EMP-05] Chỉ Admin hoặc Warehouse_Manager được hủy (Cancelled) đơn hàng.';
            END IF;
            IF EXISTS (SELECT 1 FROM shipment WHERE po_id = NEW.po_id AND status = 'Delivered') THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-PO-06] Không hủy đơn đã có chuyến Delivered.';
            END IF;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_purchase_order_bd BEFORE DELETE ON purchase_order
FOR EACH ROW
BEGIN
    IF OLD.status <> 'Draft' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-05] Chỉ được xóa đơn hàng ở trạng thái Draft.';
    END IF;
END$$

CREATE TRIGGER trg_purchase_order_ai AFTER INSERT ON purchase_order
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, record_key, action, old_value, new_value, employee_id, changed_at)
    VALUES ('PURCHASE_ORDER', NEW.po_id, 'CREATE', NULL, NEW.status, @current_employee_id, NOW());
END$$

CREATE TRIGGER trg_purchase_order_au AFTER UPDATE ON purchase_order
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status THEN
        INSERT INTO audit_log (table_name, record_key, action, old_value, new_value, employee_id, changed_at)
        VALUES ('PURCHASE_ORDER', NEW.po_id, 'STATUS_CHANGE', OLD.status, NEW.status,
                @current_employee_id, NOW());

        IF NEW.status = 'Received' THEN                         -- BR-PO-11, FR-12
            INSERT INTO stock_movement
                (warehouse_id, product_id, movement_type, quantity, movement_time,
                 employee_id, po_id, note)
            SELECT NEW.warehouse_id, od.product_id, 'Receipt', od.quantity, NOW(),
                   @current_employee_id, NEW.po_id, CONCAT('Nhập kho từ đơn ', NEW.po_id)
              FROM order_detail od
             WHERE od.po_id = NEW.po_id;
        ELSEIF NEW.status = 'Cancelled' THEN                    -- BR-PO-06
            UPDATE shipment
               SET status = 'Rejected'
             WHERE po_id = NEW.po_id AND status IN ('Planned', 'In_Transit');
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- J. Trigger: ORDER_DETAIL
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_order_detail_bi BEFORE INSERT ON order_detail
FOR EACH ROW
BEGIN
    DECLARE v_po_status  VARCHAR(20);
    DECLARE v_po_wh      VARCHAR(10);
    DECLARE v_type       VARCHAR(20);
    DECLARE v_status     VARCHAR(20);
    DECLARE v_temp       DECIMAL(4,1);

    SET v_po_status = (SELECT status       FROM purchase_order WHERE po_id = NEW.po_id);
    SET v_po_wh     = (SELECT warehouse_id FROM purchase_order WHERE po_id = NEW.po_id);
    SET v_type      = (SELECT product_type FROM product WHERE product_id = NEW.product_id);
    SET v_status    = (SELECT status       FROM product WHERE product_id = NEW.product_id);
    SET v_temp      = (SELECT storage_temp FROM product WHERE product_id = NEW.product_id);

    IF v_po_status IS NULL OR v_po_status <> 'Draft' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-07] Chỉ được thêm dòng chi tiết khi đơn hàng đang ở trạng thái Draft.';
    END IF;
    IF v_type <> 'RAW_MATERIAL' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-OD-03] Chỉ được đặt mua mặt hàng thuộc lớp con RAW_MATERIAL.';
    END IF;
    IF v_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-OD-03] Chỉ được đặt mua mặt hàng đang ở trạng thái Active (BR-PR-09).';
    END IF;
    IF NOT fn_is_storage_compatible(v_po_wh, NEW.product_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-09] Kho nhận có loại kho không tương thích với loại bảo quản của mặt hàng.';
    END IF;
    SET NEW.required_temp = v_temp;                             -- BR-OD-06: snapshot từ PRODUCT
END$$

CREATE TRIGGER trg_order_detail_bu BEFORE UPDATE ON order_detail
FOR EACH ROW
BEGIN
    IF (SELECT status FROM purchase_order WHERE po_id = OLD.po_id) <> 'Draft' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-07] Chỉ được sửa dòng chi tiết khi đơn hàng đang ở trạng thái Draft.';
    END IF;
    IF NEW.po_id <> OLD.po_id OR NEW.product_id <> OLD.product_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-OD-01] Không được sửa khóa (po_id, product_id) của dòng chi tiết.';
    END IF;
    SET NEW.required_temp = OLD.required_temp;                  -- snapshot bất biến
END$$

CREATE TRIGGER trg_order_detail_bd BEFORE DELETE ON order_detail
FOR EACH ROW
BEGIN
    IF (SELECT status FROM purchase_order WHERE po_id = OLD.po_id) <> 'Draft' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-PO-07] Chỉ được xóa dòng chi tiết khi đơn hàng đang ở trạng thái Draft.';
    END IF;
END$$

-- BR-PO-13: total_amount = Σ quantity x unit_price, tính lại sau mỗi thay đổi dòng chi tiết
CREATE TRIGGER trg_order_detail_ai AFTER INSERT ON order_detail
FOR EACH ROW
BEGIN
    UPDATE purchase_order
       SET total_amount = (SELECT COALESCE(SUM(quantity * unit_price), 0)
                             FROM order_detail WHERE po_id = NEW.po_id)
     WHERE po_id = NEW.po_id;
END$$

CREATE TRIGGER trg_order_detail_au AFTER UPDATE ON order_detail
FOR EACH ROW
BEGIN
    UPDATE purchase_order
       SET total_amount = (SELECT COALESCE(SUM(quantity * unit_price), 0)
                             FROM order_detail WHERE po_id = NEW.po_id)
     WHERE po_id = NEW.po_id;
END$$

CREATE TRIGGER trg_order_detail_ad AFTER DELETE ON order_detail
FOR EACH ROW
BEGIN
    UPDATE purchase_order
       SET total_amount = (SELECT COALESCE(SUM(quantity * unit_price), 0)
                             FROM order_detail WHERE po_id = OLD.po_id)
     WHERE po_id = OLD.po_id;
END$$

-- ---------------------------------------------------------------------
-- K. Trigger: SHIPMENT (máy trạng thái, chuỗi lạnh)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_shipment_bi BEFORE INSERT ON shipment
FOR EACH ROW
BEGIN
    DECLARE v_po_status  VARCHAR(20);
    DECLARE v_order_date DATE;

    IF NEW.status <> 'Planned' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-10] Chuyến vận chuyển mới bắt buộc ở trạng thái Planned.';
    END IF;
    IF NEW.departure_temp IS NOT NULL OR NEW.arrival_temp IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-EMP-07] Nhiệt độ chỉ được tài xế ghi nhận sau khi chuyến đã được tạo.';
    END IF;
    SET NEW.cold_chain_breach = FALSE;

    SET v_po_status  = (SELECT status     FROM purchase_order WHERE po_id = NEW.po_id);
    SET v_order_date = (SELECT order_date FROM purchase_order WHERE po_id = NEW.po_id);
    IF v_po_status IS NULL OR v_po_status NOT IN ('Confirmed', 'Shipping') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-02] Chuyến chỉ gắn với đơn hàng đang ở trạng thái Confirmed hoặc Shipping.';
    END IF;
    IF DATE(NEW.est_arrival) < v_order_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-07] est_arrival không được sớm hơn ngày tạo đơn đặt hàng.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM employee
                    WHERE employee_id = NEW.driver_id AND role = 'Driver' AND is_active = TRUE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-04] Tài xế phải là nhân viên role Driver đang hoạt động.';
    END IF;
END$$

CREATE TRIGGER trg_shipment_bu BEFORE UPDATE ON shipment
FOR EACH ROW
BEGIN
    DECLARE v_ceiling DECIMAL(5,1);

    IF OLD.status IN ('Delivered', 'Rejected') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-10] Chuyến đã Delivered/Rejected: không được thay đổi hoặc quay ngược.';
    END IF;
    IF NEW.po_id <> OLD.po_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-02] Không được đổi đơn đặt hàng của một chuyến vận chuyển.';
    END IF;
    IF NEW.driver_id <> OLD.driver_id
       AND NOT EXISTS (SELECT 1 FROM employee
                        WHERE employee_id = NEW.driver_id AND role = 'Driver' AND is_active = TRUE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-04] Tài xế phải là nhân viên role Driver đang hoạt động.';
    END IF;

    -- BR-EMP-07: chỉ đúng tài xế của chuyến mới được ghi nhiệt độ
    IF NOT (NEW.departure_temp <=> OLD.departure_temp)
       OR NOT (NEW.arrival_temp <=> OLD.arrival_temp) THEN
        IF NOT (fn_actor_role() <=> 'Driver') OR NOT (@current_employee_id <=> NEW.driver_id) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-EMP-07] Chỉ tài xế phụ trách chuyến (role Driver) mới được ghi nhiệt độ.';
        END IF;
    END IF;

    SET NEW.cold_chain_breach = OLD.cold_chain_breach;          -- không cho sửa tay

    IF NEW.status <> OLD.status THEN
        IF NOT ((OLD.status = 'Planned'    AND NEW.status IN ('In_Transit', 'Rejected'))
             OR (OLD.status = 'In_Transit' AND NEW.status IN ('Delivered', 'Rejected'))) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = '[BR-SHP-10] Chuyển trạng thái chuyến không hợp lệ (Planned → In_Transit → Delivered).';
        END IF;

        IF NEW.status = 'In_Transit' THEN
            IF NEW.departure_time IS NULL THEN
                SET NEW.departure_time = NOW();
            END IF;
        ELSEIF NEW.status = 'Delivered' THEN
            IF NEW.departure_temp IS NULL OR NEW.arrival_temp IS NULL THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = '[BR-SHP-08] Giao hàng (Delivered) bắt buộc có nhiệt độ xuất phát và nhiệt độ đến.';
            END IF;
            IF NEW.actual_arrival IS NULL THEN
                SET NEW.actual_arrival = NOW();
            END IF;
            SET v_ceiling = fn_cold_chain_ceiling(NEW.po_id);
            IF NEW.departure_temp > v_ceiling OR NEW.arrival_temp > v_ceiling THEN
                SET NEW.cold_chain_breach = TRUE;               -- BR-SHP-08
                SET NEW.status = 'Rejected';                    -- BR-SHP-09: không được nhập kho
            END IF;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_shipment_bd BEFORE DELETE ON shipment
FOR EACH ROW
BEGIN
    IF OLD.status IN ('Delivered', 'Rejected') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '[BR-SHP-11] Không xóa chuyến đã Delivered/Rejected (lưu hồ sơ truy xuất ≥ 3 năm).';
    END IF;
END$$

CREATE TRIGGER trg_shipment_ai AFTER INSERT ON shipment
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, record_key, action, old_value, new_value, employee_id, changed_at)
    VALUES ('SHIPMENT', NEW.shipment_id, 'CREATE', NULL, NEW.status, @current_employee_id, NOW());
END$$

CREATE TRIGGER trg_shipment_au AFTER UPDATE ON shipment
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status THEN
        INSERT INTO audit_log (table_name, record_key, action, old_value, new_value, employee_id, changed_at)
        VALUES ('SHIPMENT', NEW.shipment_id, 'STATUS_CHANGE', OLD.status, NEW.status,
                @current_employee_id, NOW());

        IF NEW.status = 'In_Transit' THEN                       -- BR-PO-14
            UPDATE purchase_order
               SET status = 'Shipping'
             WHERE po_id = NEW.po_id AND status = 'Confirmed';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- L. Procedure nghiệp vụ (giao dịch ACID - NFR-03; người dùng chỉ cần quyền EXECUTE)
-- ---------------------------------------------------------------------

-- Gắn người thao tác: nếu đăng nhập bằng tài khoản EMP-xxxxxx thì lấy chính tài khoản đó
-- (không cho mạo danh); nếu không (tài khoản quản trị/kiểm thử) thì dùng p_actor.
CREATE PROCEDURE sp_bind_actor(IN p_actor VARCHAR(10))
BEGIN
    DECLARE v_login VARCHAR(64);
    SET v_login = SUBSTRING_INDEX(USER(), '@', 1);
    IF v_login REGEXP '^EMP-[0-9]{6}$' THEN
        SET @current_employee_id = v_login;
    ELSE
        SET @current_employee_id = p_actor;
    END IF;
END$$

CREATE PROCEDURE sp_change_po_status(
    IN p_po_id VARCHAR(15), IN p_new_status VARCHAR(20), IN p_actor VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    CALL sp_bind_actor(p_actor);
    IF NOT EXISTS (SELECT 1 FROM purchase_order WHERE po_id = p_po_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không tìm thấy đơn đặt hàng.';
    END IF;
    START TRANSACTION;
    UPDATE purchase_order SET status = p_new_status WHERE po_id = p_po_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_confirm_purchase_order(IN p_po_id VARCHAR(15), IN p_actor VARCHAR(10))
BEGIN
    CALL sp_change_po_status(p_po_id, 'Confirmed', p_actor);
END$$

CREATE PROCEDURE sp_cancel_purchase_order(IN p_po_id VARCHAR(15), IN p_actor VARCHAR(10))
BEGIN
    CALL sp_change_po_status(p_po_id, 'Cancelled', p_actor);
END$$

-- Nhận hàng: một giao dịch cập nhật đồng thời PURCHASE_ORDER, STOCK_MOVEMENT, INVENTORY,
-- INVENTORY_ALERT, AUDIT_LOG; lỗi ở bất kỳ bước nào sẽ hoàn tác toàn bộ (NFR-03).
CREATE PROCEDURE sp_receive_purchase_order(IN p_po_id VARCHAR(15), IN p_actor VARCHAR(10))
BEGIN
    CALL sp_change_po_status(p_po_id, 'Received', p_actor);
END$$

CREATE PROCEDURE sp_start_shipment(
    IN p_shipment_id VARCHAR(15), IN p_departure_temp DECIMAL(4,1), IN p_actor VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    CALL sp_bind_actor(p_actor);
    START TRANSACTION;
    UPDATE shipment
       SET departure_temp = p_departure_temp,
           departure_time = IFNULL(departure_time, NOW()),
           status = 'In_Transit'
     WHERE shipment_id = p_shipment_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_complete_shipment(
    IN p_shipment_id VARCHAR(15), IN p_arrival_temp DECIMAL(4,1), IN p_actor VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    CALL sp_bind_actor(p_actor);
    START TRANSACTION;
    UPDATE shipment
       SET arrival_temp = p_arrival_temp,
           actual_arrival = NOW(),
           status = 'Delivered'          -- trigger tự chuyển sang Rejected nếu vi phạm chuỗi lạnh
     WHERE shipment_id = p_shipment_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_record_stock_movement(
    IN p_warehouse_id VARCHAR(10), IN p_product_id VARCHAR(10), IN p_type VARCHAR(20),
    IN p_quantity DECIMAL(12,3),   IN p_actor VARCHAR(10),      IN p_note VARCHAR(255))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    CALL sp_bind_actor(p_actor);
    START TRANSACTION;
    INSERT INTO stock_movement
        (warehouse_id, product_id, movement_type, quantity, employee_id, po_id, note)
    VALUES (p_warehouse_id, p_product_id, p_type, p_quantity, @current_employee_id, NULL, p_note);
    COMMIT;
END$$

-- Truy xuất nguồn gốc (FR-14, NFR-02): từ một thành phẩm -> nguyên liệu (đa cấp) -> đơn hàng -> nhà cung cấp
CREATE PROCEDURE sp_trace_finished_good(IN p_product_id VARCHAR(10))
BEGIN
    WITH RECURSIVE bom (component_id, depth, qty_per_unit) AS (
        SELECT c.component_product_id, 1,
               c.quantity_required * (1 + c.wastage_rate / 100)
          FROM v_bom_current c
         WHERE c.parent_product_id = p_product_id
        UNION ALL
        SELECT c.component_product_id, b.depth + 1,
               b.qty_per_unit * c.quantity_required * (1 + c.wastage_rate / 100)
          FROM bom b
          JOIN v_bom_current c ON c.parent_product_id = b.component_id
    )
    SELECT b.depth, rm.product_id AS raw_material_id, rm.product_name AS raw_material_name,
           ROUND(b.qty_per_unit, 4) AS qty_per_finished_unit,
           po.po_id, po.order_date, s.supplier_id, s.supplier_name, w.warehouse_id
      FROM bom b
      JOIN product rm        ON rm.product_id = b.component_id
                            AND rm.product_type = 'RAW_MATERIAL'
      JOIN order_detail od   ON od.product_id = rm.product_id
      JOIN purchase_order po ON po.po_id = od.po_id AND po.status = 'Received'
      JOIN supplier s        ON s.supplier_id = po.supplier_id
      JOIN warehouse w       ON w.warehouse_id = po.warehouse_id
     ORDER BY b.depth, rm.product_id, po.order_date;
END$$


-- Thêm nhân viên: mã hóa phone bằng fn_encrypt_phone + @app_key (NFR-04).
-- DML gọi: CALL sp_add_employee(id, name, phone, role, warehouse_id, key);
CREATE PROCEDURE sp_add_employee(
    IN p_employee_id   VARCHAR(10),
    IN p_full_name     VARCHAR(100),
    IN p_phone         VARCHAR(15),
    IN p_role          VARCHAR(30),
    IN p_warehouse_id  VARCHAR(10),
    IN p_key           VARCHAR(64)
)
BEGIN
    SET @app_key = p_key;
    INSERT INTO employee (employee_id, full_name, phone, role, warehouse_id, is_active)
    VALUES (
        p_employee_id,
        p_full_name,
        fn_encrypt_phone(p_phone),
        p_role,
        p_warehouse_id,
        TRUE
    );
END$$

-- Giải mã số điện thoại nhân viên (NFR-04). Q16 gọi procedure này.
CREATE PROCEDURE sp_get_employee_phone(
    IN p_employee_id VARCHAR(10),
    IN p_key         VARCHAR(64)
)
BEGIN
    SET @app_key = p_key;
    SELECT e.employee_id,
           e.full_name,
           fn_decrypt_phone(e.phone) AS phone,
           e.role,
           e.warehouse_id,
           e.is_active
      FROM employee AS e
     WHERE e.employee_id = p_employee_id;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- M. View
-- ---------------------------------------------------------------------

-- Định mức hiện hành: mỗi thành phẩm chỉ lấy phiên bản có effective_date mới nhất <= hôm nay (BR-BOM-08)
CREATE VIEW v_bom_current AS
SELECT pc.parent_product_id, pc.component_product_id, pc.effective_date,
       pc.quantity_required, pc.wastage_rate
  FROM product_component pc
 WHERE pc.effective_date = (SELECT MAX(x.effective_date)
                              FROM product_component x
                             WHERE x.parent_product_id = pc.parent_product_id
                               AND x.effective_date <= CURDATE());

-- Hàng sắp hết (quantity <= reorder_level) kèm thời điểm cảnh báo đang mở
CREATE VIEW v_low_stock AS
SELECT w.warehouse_id, w.warehouse_name, p.product_id, p.product_name, p.unit,
       i.quantity, i.reorder_level, (i.reorder_level - i.quantity) AS shortage,
       a.created_at AS alert_since
  FROM inventory i
  JOIN warehouse w ON w.warehouse_id = i.warehouse_id
  JOIN product p   ON p.product_id   = i.product_id
  LEFT JOIN inventory_alert a ON a.warehouse_id = i.warehouse_id
                             AND a.product_id   = i.product_id
                             AND a.status = 'Open'
 WHERE i.quantity <= i.reorder_level;

-- Mức sử dụng sức chứa của từng kho
CREATE VIEW v_warehouse_utilization AS
SELECT w.warehouse_id, w.warehouse_name, w.warehouse_type, w.capacity_m3,
       COALESCE(SUM(i.quantity * p.volume_m3), 0) AS used_m3,
       ROUND(COALESCE(SUM(i.quantity * p.volume_m3), 0) / w.capacity_m3 * 100, 2) AS used_percent
  FROM warehouse w
  LEFT JOIN inventory i ON i.warehouse_id = w.warehouse_id
  LEFT JOIN product p   ON p.product_id   = i.product_id
 GROUP BY w.warehouse_id, w.warehouse_name, w.warehouse_type, w.capacity_m3;

-- Truy xuất nguồn gốc theo phiếu nhập: hàng nào, từ đơn nào, nhà cung cấp nào, chuyến nào, nhiệt độ ra sao
CREATE VIEW v_receipt_traceability AS
SELECT sm.movement_id, sm.movement_time, p.product_id, p.product_name, sm.quantity,
       po.po_id, po.order_date, s.supplier_id, s.supplier_name, w.warehouse_id,
       sh.shipment_id, sh.vehicle_plate, sh.driver_id,
       sh.departure_temp, sh.arrival_temp, sh.cold_chain_breach
  FROM stock_movement sm
  JOIN purchase_order po ON po.po_id = sm.po_id
  JOIN supplier s        ON s.supplier_id = po.supplier_id
  JOIN product p         ON p.product_id = sm.product_id
  JOIN warehouse w       ON w.warehouse_id = sm.warehouse_id
  LEFT JOIN shipment sh  ON sh.po_id = po.po_id AND sh.status = 'Delivered'
 WHERE sm.movement_type = 'Receipt';

-- Kiểm tra tính toàn phần của chuyên biệt hóa: mặt hàng chưa có bản ghi ở bảng con (phải rỗng)
CREATE VIEW v_product_missing_subtype AS
SELECT p.product_id, p.product_type
  FROM product p
  LEFT JOIN raw_material rm  ON rm.product_id = p.product_id
  LEFT JOIN finished_good fg ON fg.product_id = p.product_id
 WHERE (p.product_type = 'RAW_MATERIAL'  AND rm.product_id IS NULL)
    OR (p.product_type = 'FINISHED_GOOD' AND fg.product_id IS NULL);

-- Danh bạ nhân viên: bản đầy đủ (giải mã số điện thoại - chỉ cấp cho Admin) và bản công khai
CREATE VIEW v_employee_directory AS
SELECT e.employee_id, e.full_name, fn_decrypt_phone(e.phone) AS phone,
       e.role, e.warehouse_id, e.is_active
  FROM employee e;

CREATE VIEW v_employee_public AS
SELECT e.employee_id, e.full_name, e.role, e.warehouse_id, e.is_active
  FROM employee e;

-- View cô lập theo người dùng (RBAC mức dòng, BR-EMP-06): tài khoản CSDL đặt theo mã nhân viên
CREATE VIEW v_my_inventory AS
SELECT i.warehouse_id, i.product_id, p.product_name, p.unit,
       i.quantity, i.reorder_level, i.max_capacity, i.last_updated
  FROM inventory i
  JOIN product p  ON p.product_id = i.product_id
  JOIN employee e ON e.warehouse_id = i.warehouse_id
 WHERE e.employee_id = SUBSTRING_INDEX(USER(), '@', 1);

CREATE VIEW v_my_shipments AS
SELECT sh.shipment_id, sh.po_id, sh.vehicle_plate, sh.departure_time, sh.est_arrival,
       sh.actual_arrival, sh.departure_temp, sh.arrival_temp, sh.status
  FROM shipment sh
 WHERE sh.driver_id = SUBSTRING_INDEX(USER(), '@', 1);