USE cold_chain_db;
SET NAMES utf8mb4;
SET SESSION block_encryption_mode = 'aes-256-cbc';
SET SQL_SAFE_UPDATES = 0;          
SET @aes_key = 'Eternal@PTIT2026'; 
SET @current_employee_id = NULL;

-- 1. WAREHOUSE (manager_id stays NULL until the manager exists, BR-WH-09)
INSERT INTO warehouse (
    warehouse_id, warehouse_name, address, city, country, phone,
    warehouse_type, area_m2, capacity_m3, storage_temp, is_active
)
VALUES
    ('WH-CL-01', 'Kho mát Tân Thuận', '12 Đường Tân Thuận', 'TP. Hồ Chí Minh', 'Việt Nam', '0283800001', 'Cold', 2500.0, 6000.0, 2.0, TRUE),
    ('WH-CL-02', 'Kho mát Cần Thơ', '88 Quốc lộ 91B', 'Cần Thơ', 'Việt Nam', '0292800002', 'Cold', 1800.0, 4500.0, 2.0, TRUE),
    ('WH-CL-03', 'Kho mát Đà Nẵng', '25 Nguyễn Tất Thành', 'Đà Nẵng', 'Việt Nam', '0236800003', 'Cold', 2200.0, 5200.0, 3.0, TRUE),
    ('WH-CL-04', 'Kho mát Huế (tạm ngừng)', '9 Đường Phú Bài', 'Huế', 'Việt Nam', NULL, 'Cold', 900.0, 2000.0, 2.0, FALSE),
    ('WH-FZ-01', 'Kho đông Hiệp Phước', '310 Nguyễn Văn Tạo', 'TP. Hồ Chí Minh', 'Việt Nam', '0283800011', 'Frozen', 4200.0, 9500.0, -20.0, TRUE),
    ('WH-FZ-02', 'Kho đông Hải Phòng', '45 Đường Đình Vũ', 'Hải Phòng', 'Việt Nam', '0225800012', 'Frozen', 3600.0, 8000.0, -22.0, TRUE),
    ('WH-FZ-03', 'Kho đông Nha Trang', '17 Đường Vĩnh Lương', 'Nha Trang', 'Việt Nam', '0258800013', 'Frozen', 3000.0, 7000.0, -20.0, TRUE);

-- 2. EMPLOYEE (phone is AES-encrypted by sp_add_employee, NFR-04)
CALL sp_add_employee('EMP-000001', 'Nguyễn Minh Quân', '0901000001', 'Admin', NULL, @aes_key);
CALL sp_add_employee('EMP-000011', 'Trần Thị Hồng Nhung', '0901000011', 'Warehouse_Manager', 'WH-CL-01', @aes_key);
CALL sp_add_employee('EMP-000012', 'Lê Văn Hải', '0901000012', 'Warehouse_Manager', 'WH-CL-02', @aes_key);
CALL sp_add_employee('EMP-000013', 'Phạm Thu Hà', '0901000013', 'Warehouse_Manager', 'WH-CL-03', @aes_key);
CALL sp_add_employee('EMP-000014', 'Võ Đức Thịnh', '0901000014', 'Warehouse_Manager', 'WH-FZ-01', @aes_key);
CALL sp_add_employee('EMP-000015', 'Đặng Thị Mai', '0901000015', 'Warehouse_Manager', 'WH-FZ-02', @aes_key);
CALL sp_add_employee('EMP-000016', 'Bùi Quang Huy', '0901000016', 'Warehouse_Manager', 'WH-FZ-03', @aes_key);
CALL sp_add_employee('EMP-000021', 'Hoàng Thị Lan', '0901000021', 'Warehouse_Staff', 'WH-CL-01', @aes_key);
CALL sp_add_employee('EMP-000022', 'Ngô Văn Bình', '0901000022', 'Warehouse_Staff', 'WH-CL-01', @aes_key);
CALL sp_add_employee('EMP-000023', 'Đỗ Thị Thu', '0901000023', 'Warehouse_Staff', 'WH-CL-02', @aes_key);
CALL sp_add_employee('EMP-000024', 'Lý Văn Sơn', '0901000024', 'Warehouse_Staff', 'WH-CL-02', @aes_key);
CALL sp_add_employee('EMP-000025', 'Phan Thị Yến', '0901000025', 'Warehouse_Staff', 'WH-CL-03', @aes_key);
CALL sp_add_employee('EMP-000026', 'Vũ Văn Tài', '0901000026', 'Warehouse_Staff', 'WH-CL-03', @aes_key);
CALL sp_add_employee('EMP-000027', 'Trương Thị Ngọc', '0901000027', 'Warehouse_Staff', 'WH-FZ-01', @aes_key);
CALL sp_add_employee('EMP-000028', 'Dương Văn Khoa', '0901000028', 'Warehouse_Staff', 'WH-FZ-01', @aes_key);
CALL sp_add_employee('EMP-000029', 'Mai Thị Oanh', '0901000029', 'Warehouse_Staff', 'WH-FZ-02', @aes_key);
CALL sp_add_employee('EMP-000030', 'Cao Văn Đạt', '0901000030', 'Warehouse_Staff', 'WH-FZ-02', @aes_key);
CALL sp_add_employee('EMP-000031', 'Tạ Thị Bích', '0901000031', 'Warehouse_Staff', 'WH-FZ-03', @aes_key);
CALL sp_add_employee('EMP-000032', 'Hồ Văn Lộc', '0901000032', 'Warehouse_Staff', 'WH-FZ-03', @aes_key);
CALL sp_add_employee('EMP-000041', 'Nguyễn Văn Tâm', '0901000041', 'Driver', NULL, @aes_key);
CALL sp_add_employee('EMP-000042', 'Lê Quốc Việt', '0901000042', 'Driver', NULL, @aes_key);
CALL sp_add_employee('EMP-000043', 'Trần Văn Phát', '0901000043', 'Driver', NULL, @aes_key);
CALL sp_add_employee('EMP-000044', 'Phạm Văn Nghĩa', '0901000044', 'Driver', NULL, @aes_key);
CALL sp_add_employee('EMP-000045', 'Huỳnh Văn Thành', '0901000045', 'Driver', NULL, @aes_key);
-- EMP-000045 left the company (BR-EMP-03 / BR-SHP-04 test data)
UPDATE employee SET is_active = FALSE WHERE employee_id = 'EMP-000045';

-- 3. assign warehouse managers (trg_warehouse_bu checks role and warehouse)
UPDATE warehouse SET manager_id = 'EMP-000011' WHERE warehouse_id = 'WH-CL-01';
UPDATE warehouse SET manager_id = 'EMP-000012' WHERE warehouse_id = 'WH-CL-02';
UPDATE warehouse SET manager_id = 'EMP-000013' WHERE warehouse_id = 'WH-CL-03';
UPDATE warehouse SET manager_id = 'EMP-000014' WHERE warehouse_id = 'WH-FZ-01';
UPDATE warehouse SET manager_id = 'EMP-000015' WHERE warehouse_id = 'WH-FZ-02';
UPDATE warehouse SET manager_id = 'EMP-000016' WHERE warehouse_id = 'WH-FZ-03';

-- 4. SUPPLIER and SUPPLIER_CERTIFICATE
INSERT INTO supplier (
    supplier_id, supplier_name, supplier_type, contact_name,
    phone, email, address, is_active
)
VALUES
    ('SUP-001', 'Công ty Hải sản Biển Đông', 'Trading_Agent', 'Phạm Văn Long', '0911000001', 'bien.dong@seafood.example', '15 Đường Cảng, Vũng Tàu', TRUE),
    ('SUP-002', 'Tàu cá Bình Định 01', 'Fishing_Vessel', 'Nguyễn Văn Hùng', '0911000002', 'bd01@seafood.example', 'Cảng Quy Nhơn, Bình Định', TRUE),
    ('SUP-003', 'Đại lý thu mua cảng Cát Lái', 'Trading_Agent', 'Lê Thị Tuyết', '0911000003', 'catlai@seafood.example', 'Cảng Cát Lái, TP. Hồ Chí Minh', TRUE),
    ('SUP-004', 'Công ty Nhập khẩu Seafood Pacific', 'Importer', 'Trần Quốc Bảo', '0911000004', 'pacific@seafood.example', 'Quận 7, TP. Hồ Chí Minh', TRUE),
    ('SUP-005', 'Tàu cá Kiên Giang 07', 'Fishing_Vessel', 'Võ Văn Thanh', '0911000005', NULL, 'Cảng Rạch Giá, Kiên Giang', TRUE),
    ('SUP-006', 'Hợp tác xã Nuôi trồng Cà Mau', 'Trading_Agent', 'Đinh Thị Hoa', '0911000006', 'camau@seafood.example', 'Năm Căn, Cà Mau', TRUE),
    ('SUP-007', 'Đại lý Hải sản Phan Thiết', 'Trading_Agent', NULL, '0911000007', 'phanthiet@seafood.example', 'Cảng Phan Thiết, Bình Thuận', TRUE),
    ('SUP-008', 'Công ty Nhập khẩu Ocean Star', 'Importer', 'Hoàng Minh Tuấn', '0911000008', 'oceanstar@seafood.example', 'Quận 4, TP. Hồ Chí Minh', FALSE);

INSERT INTO supplier_certificate (cert_number, supplier_id, cert_expiry_date)
VALUES
    ('HACCP-2025-0001', 'SUP-001', '2027-06-30'),
    ('ISO22000-2025-0001', 'SUP-001', '2027-12-31'),
    ('HACCP-2025-0002', 'SUP-002', '2027-03-31'),
    ('HACCP-2025-0003', 'SUP-003', '2027-09-30'),
    ('ISO22000-2025-0003', 'SUP-003', '2028-01-31'),
    ('HACCP-2025-0004', 'SUP-004', '2027-11-30'),
    ('HACCP-2025-0005', 'SUP-005', '2027-05-31'),
    ('HACCP-2025-0006', 'SUP-006', '2027-08-31'),
    ('HACCP-2023-0007', 'SUP-007', '2025-12-31'),
    ('HACCP-2025-0008', 'SUP-008', '2027-10-31');

-- 5. PRODUCT (parent) then RAW_MATERIAL / FINISHED_GOOD (children)
INSERT INTO product (
    product_id, product_code, product_name, product_type,
    storage_type, storage_temp, unit, weight_kg, volume_m3, status
)
VALUES
    ('RM-000001', 'SKU-RM-000001', 'Cá thu tươi', 'RAW_MATERIAL', 'Chilled', 2.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000002', 'SKU-RM-000002', 'Tôm sú tươi', 'RAW_MATERIAL', 'Chilled', 2.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000003', 'SKU-RM-000003', 'Mực ống tươi', 'RAW_MATERIAL', 'Chilled', 2.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000004', 'SKU-RM-000004', 'Cua biển tươi', 'RAW_MATERIAL', 'Chilled', 2.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000005', 'SKU-RM-000005', 'Sò điệp tươi', 'RAW_MATERIAL', 'Chilled', 2.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000006', 'SKU-RM-000006', 'Cá thát lát phi lê', 'RAW_MATERIAL', 'Chilled', 2.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000007', 'SKU-RM-000007', 'Tôm thẻ đông lạnh', 'RAW_MATERIAL', 'Frozen', -20.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000008', 'SKU-RM-000008', 'Mực nang đông lạnh', 'RAW_MATERIAL', 'Frozen', -20.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000009', 'SKU-RM-000009', 'Cá basa phi lê đông lạnh', 'RAW_MATERIAL', 'Frozen', -20.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000010', 'SKU-RM-000010', 'Ghẹ đông lạnh', 'RAW_MATERIAL', 'Frozen', -20.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000011', 'SKU-RM-000011', 'Nghêu đông lạnh', 'RAW_MATERIAL', 'Frozen', -20.0, 'kg', 1.0, 0.002, 'Active'),
    ('RM-000012', 'SKU-RM-000012', 'Cá ngừ đại dương đông lạnh', 'RAW_MATERIAL', 'Frozen', -20.0, 'kg', 1.0, 0.002, 'Active'),
    ('FG-000001', 'SKU-FG-000001', 'Lẩu hải sản đông lạnh', 'FINISHED_GOOD', 'Frozen', -20.0, 'box', 5.0, 0.012, 'Draft'),
    ('FG-000002', 'SKU-FG-000002', 'Chả cá viên', 'FINISHED_GOOD', 'Frozen', -20.0, 'box', 5.0, 0.012, 'Draft'),
    ('FG-000003', 'SKU-FG-000003', 'Tôm tẩm bột đông lạnh', 'FINISHED_GOOD', 'Frozen', -20.0, 'box', 5.0, 0.012, 'Draft'),
    ('FG-000004', 'SKU-FG-000004', 'Cá thát lát tươi đóng khay', 'FINISHED_GOOD', 'Chilled', 2.0, 'box', 5.0, 0.012, 'Draft'),
    ('FG-000005', 'SKU-FG-000005', 'Mực nhồi thịt', 'FINISHED_GOOD', 'Frozen', -20.0, 'box', 5.0, 0.012, 'Draft'),
    ('FG-000006', 'SKU-FG-000006', 'Combo hải sản nướng', 'FINISHED_GOOD', 'Frozen', -20.0, 'box', 5.0, 0.012, 'Draft'),
    ('FG-000007', 'SKU-FG-000007', 'Sushi cá ngừ đóng gói', 'FINISHED_GOOD', 'Chilled', 2.0, 'box', 5.0, 0.012, 'Draft'),
    ('FG-000008', 'SKU-FG-000008', 'Chả cá thát lát chiên', 'FINISHED_GOOD', 'Chilled', 2.0, 'box', 5.0, 0.012, 'Draft');
INSERT INTO raw_material (product_id, default_supplier_id, expiry_days, catch_area)
VALUES
    ('RM-000001', 'SUP-001', 5, 'Vũng Tàu'),
    ('RM-000002', 'SUP-002', 3, 'Bình Định'),
    ('RM-000003', 'SUP-003', 4, 'Cát Lái'),
    ('RM-000004', 'SUP-004', 3, 'Cà Mau'),
    ('RM-000005', 'SUP-001', 4, 'Vũng Tàu'),
    ('RM-000006', 'SUP-006', 5, 'Cà Mau'),
    ('RM-000007', 'SUP-002', 365, 'Bình Định'),
    ('RM-000008', 'SUP-003', 365, 'Kiên Giang'),
    ('RM-000009', 'SUP-005', 365, 'Đồng Tháp'),
    ('RM-000010', 'SUP-005', 300, 'Kiên Giang'),
    ('RM-000011', 'SUP-006', 300, 'Bến Tre'),
    ('RM-000012', 'SUP-004', 365, 'Phú Yên');

INSERT INTO finished_good (product_id, expiry_months, package_spec)
VALUES
    ('FG-000001', 12, 'Hộp 5 kg'),
    ('FG-000002', 12, 'Túi 1 kg x 5'),
    ('FG-000003', 10, 'Khay 500 g x 10'),
    ('FG-000004', 1, 'Khay 500 g x 10'),
    ('FG-000005', 10, 'Hộp 5 kg'),
    ('FG-000006', 9, 'Hộp 5 kg'),
    ('FG-000007', 1, 'Hộp 5 kg'),
    ('FG-000008', 2, 'Hộp 5 kg');

-- 6. PRODUCT_COMPONENT (bill of materials, includes a 2-level BOM and a versioned row)
INSERT INTO product_component (
    parent_product_id, component_product_id, effective_date,
    quantity_required, wastage_rate
)
VALUES
    ('FG-000001', 'RM-000007', '2026-01-01', 0.5, 3.0),
    ('FG-000001', 'RM-000007', '2026-07-01', 0.55, 3.0),
    ('FG-000001', 'RM-000008', '2026-01-01', 0.3, 4.0),
    ('FG-000001', 'RM-000010', '2026-01-01', 0.25, 5.0),
    ('FG-000001', 'RM-000011', '2026-01-01', 0.4, 2.0),
    ('FG-000002', 'RM-000009', '2026-01-01', 0.8, 4.0),
    ('FG-000002', 'RM-000012', '2026-01-01', 0.1, 2.0),
    ('FG-000003', 'RM-000007', '2026-01-01', 1.0, 5.0),
    ('FG-000004', 'RM-000006', '2026-01-01', 1.2, 6.0),
    ('FG-000005', 'RM-000008', '2026-01-01', 0.7, 4.0),
    ('FG-000005', 'RM-000009', '2026-01-01', 0.2, 3.0),
    ('FG-000006', 'FG-000003', '2026-01-01', 2.0, 0.0),
    ('FG-000006', 'FG-000005', '2026-01-01', 1.0, 0.0),
    ('FG-000006', 'RM-000010', '2026-01-01', 0.5, 2.0),
    ('FG-000007', 'RM-000001', '2026-01-01', 0.6, 5.0),
    ('FG-000008', 'RM-000006', '2026-01-01', 0.9, 4.0),
    ('FG-000008', 'RM-000003', '2026-01-01', 0.1, 2.0);

-- Activate finished goods that now have BOM (BR-BOM-02)
UPDATE product
   SET status = 'Active'
 WHERE product_type = 'FINISHED_GOOD'
   AND status = 'Draft'
   AND EXISTS (
         SELECT 1 FROM product_component pc
          WHERE pc.parent_product_id = product.product_id
       );



-- 7. VEHICLE
INSERT INTO vehicle (vehicle_plate, vehicle_type)
VALUES
    ('51C-123.45', 'Reefer_Truck'),
    ('51C-234.56', 'Reefer_Truck'),
    ('65C-345.67', 'Reefer_Truck'),
    ('29C-456.78', 'Reefer_Truck'),
    ('51D-678.90', 'Freezer_Container'),
    ('43D-789.01', 'Freezer_Container'),
    ('15D-890.12', 'Freezer_Container');

-- 8. OPENING STOCK: Adjust_In movements by the warehouse staff.
--    The trigger creates each inventory row (reorder_level 0) and checks
--    temperature compatibility and warehouse capacity.
INSERT INTO stock_movement (
    warehouse_id, product_id, movement_type, quantity, employee_id, note
)
VALUES
    ('WH-CL-01', 'RM-000001', 'Adjust_In', 1550, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'RM-000002', 'Adjust_In', 2800, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'RM-000003', 'Adjust_In', 4000, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'RM-000004', 'Adjust_In', 1450, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'RM-000005', 'Adjust_In', 2200, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'RM-000006', 'Adjust_In', 3450, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'FG-000004', 'Adjust_In', 3000, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'FG-000007', 'Adjust_In', 2300, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-01', 'FG-000008', 'Adjust_In', 2250, 'EMP-000021', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'RM-000001', 'Adjust_In', 3900, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'RM-000002', 'Adjust_In', 3600, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'RM-000003', 'Adjust_In', 2300, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'RM-000004', 'Adjust_In', 800, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'RM-000005', 'Adjust_In', 1300, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'RM-000006', 'Adjust_In', 1500, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'FG-000004', 'Adjust_In', 1400, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'FG-000007', 'Adjust_In', 800, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-02', 'FG-000008', 'Adjust_In', 1900, 'EMP-000023', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'RM-000001', 'Adjust_In', 850, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'RM-000002', 'Adjust_In', 3900, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'RM-000003', 'Adjust_In', 2800, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'RM-000004', 'Adjust_In', 2100, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'RM-000005', 'Adjust_In', 3300, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'RM-000006', 'Adjust_In', 2400, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'FG-000004', 'Adjust_In', 1600, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'FG-000007', 'Adjust_In', 1600, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-CL-03', 'FG-000008', 'Adjust_In', 1700, 'EMP-000025', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'RM-000007', 'Adjust_In', 1250, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'RM-000008', 'Adjust_In', 2950, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'RM-000009', 'Adjust_In', 1350, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'RM-000010', 'Adjust_In', 2650, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'RM-000011', 'Adjust_In', 2600, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'RM-000012', 'Adjust_In', 3700, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'FG-000001', 'Adjust_In', 950, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'FG-000002', 'Adjust_In', 2550, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'FG-000003', 'Adjust_In', 2750, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'FG-000005', 'Adjust_In', 2750, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-01', 'FG-000006', 'Adjust_In', 2300, 'EMP-000027', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'RM-000007', 'Adjust_In', 2750, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'RM-000008', 'Adjust_In', 950, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'RM-000009', 'Adjust_In', 3150, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'RM-000010', 'Adjust_In', 3100, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'RM-000011', 'Adjust_In', 3750, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'RM-000012', 'Adjust_In', 3500, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'FG-000001', 'Adjust_In', 750, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'FG-000002', 'Adjust_In', 1750, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'FG-000003', 'Adjust_In', 2350, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'FG-000005', 'Adjust_In', 2250, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-02', 'FG-000006', 'Adjust_In', 2050, 'EMP-000029', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'RM-000007', 'Adjust_In', 1500, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'RM-000008', 'Adjust_In', 3500, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'RM-000009', 'Adjust_In', 4000, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'RM-000010', 'Adjust_In', 3900, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'RM-000011', 'Adjust_In', 3300, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'RM-000012', 'Adjust_In', 2450, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'FG-000001', 'Adjust_In', 1800, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'FG-000002', 'Adjust_In', 2300, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'FG-000003', 'Adjust_In', 2000, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'FG-000005', 'Adjust_In', 2100, 'EMP-000031', 'Tồn đầu kỳ'),
    ('WH-FZ-03', 'FG-000006', 'Adjust_In', 2150, 'EMP-000031', 'Tồn đầu kỳ');

-- default reorder level = 20 % of the opening stock
UPDATE inventory SET reorder_level = ROUND(quantity * 0.2, 0);

-- 9. PURCHASE ORDERS. Each block walks the real flow so the triggers,
--    audit_log, stock_movement and inventory are all exercised.
--    @current_employee_id = the person acting (audit trail, BR-AUD-03).

-- ---- PO-2026-00001 : SUP-001 -> WH-CL-01 [received]
SET @current_employee_id = 'EMP-000021';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00001', 'SUP-001', 'WH-CL-01', 'EMP-000021', '2026-08-03', '2026-08-08');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00001', 'RM-000001', 500, 85000),
    ('PO-2026-00001', 'RM-000002', 300, 210000),
    ('PO-2026-00001', 'RM-000003', 200, 95000);
SET @current_employee_id = 'EMP-000011';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00001';
SET @current_employee_id = 'EMP-000021';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00001', 'PO-2026-00001', 'EMP-000042', '51C-123.45', '2026-08-04 06:00:00', '2026-08-04 14:00:00');
SET @current_employee_id = 'EMP-000042';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00001';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-08-04 13:20:00', departure_temp = 2.0, arrival_temp = 3.0
 WHERE shipment_id = 'SHP-2026-00001';
SET @current_employee_id = 'EMP-000021';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00001';

-- ---- PO-2026-00002 : SUP-002 -> WH-FZ-01 [received]
SET @current_employee_id = 'EMP-000027';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00002', 'SUP-002', 'WH-FZ-01', 'EMP-000027', '2026-08-05', '2026-08-10');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00002', 'RM-000007', 400, 165000),
    ('PO-2026-00002', 'RM-000009', 600, 72000),
    ('PO-2026-00002', 'RM-000012', 150, 310000);
SET @current_employee_id = 'EMP-000014';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00002';
SET @current_employee_id = 'EMP-000027';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00002', 'PO-2026-00002', 'EMP-000043', '51D-678.90', '2026-08-06 06:00:00', '2026-08-06 14:00:00');
SET @current_employee_id = 'EMP-000043';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00002';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-08-06 13:20:00', departure_temp = -21.0, arrival_temp = -19.0
 WHERE shipment_id = 'SHP-2026-00002';
SET @current_employee_id = 'EMP-000027';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00002';

-- ---- PO-2026-00003 : SUP-003 -> WH-FZ-02 [breach_then_received]
SET @current_employee_id = 'EMP-000029';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00003', 'SUP-003', 'WH-FZ-02', 'EMP-000029', '2026-08-12', '2026-08-17');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00003', 'RM-000008', 300, 140000),
    ('PO-2026-00003', 'RM-000010', 200, 190000);
SET @current_employee_id = 'EMP-000015';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00003';
SET @current_employee_id = 'EMP-000029';
-- first shipment breaks the cold chain: trigger forces status Rejected (BR-SHP-09)
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00003', 'PO-2026-00003', 'EMP-000044', '43D-789.01', '2026-08-13 06:00:00', '2026-08-13 14:00:00');
SET @current_employee_id = 'EMP-000044';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00003';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-08-13 13:20:00', departure_temp = -20.0, arrival_temp = -12.0
 WHERE shipment_id = 'SHP-2026-00003';
SET @current_employee_id = 'EMP-000029';
-- re-delivery with a new shipment (BR-PO-10)
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00004', 'PO-2026-00003', 'EMP-000041', '15D-890.12', '2026-08-13 06:00:00', '2026-08-13 14:00:00');
SET @current_employee_id = 'EMP-000041';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00004';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-08-13 13:20:00', departure_temp = -21.0, arrival_temp = -19.0
 WHERE shipment_id = 'SHP-2026-00004';
SET @current_employee_id = 'EMP-000029';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00003';

-- ---- PO-2026-00004 : SUP-004 -> WH-CL-02 [received]
SET @current_employee_id = 'EMP-000023';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00004', 'SUP-004', 'WH-CL-02', 'EMP-000023', '2026-08-18', '2026-08-23');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00004', 'RM-000002', 250, 205000),
    ('PO-2026-00004', 'RM-000004', 120, 260000);
SET @current_employee_id = 'EMP-000012';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00004';
SET @current_employee_id = 'EMP-000023';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00005', 'PO-2026-00004', 'EMP-000042', '51C-234.56', '2026-08-19 06:00:00', '2026-08-19 14:00:00');
SET @current_employee_id = 'EMP-000042';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00005';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-08-19 13:20:00', departure_temp = 2.0, arrival_temp = 3.0
 WHERE shipment_id = 'SHP-2026-00005';
SET @current_employee_id = 'EMP-000023';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00004';

-- ---- PO-2026-00005 : SUP-006 -> WH-CL-03 [received]
SET @current_employee_id = 'EMP-000025';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00005', 'SUP-006', 'WH-CL-03', 'EMP-000025', '2026-08-25', '2026-08-30');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00005', 'RM-000006', 400, 68000),
    ('PO-2026-00005', 'RM-000001', 300, 82000);
SET @current_employee_id = 'EMP-000013';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00005';
SET @current_employee_id = 'EMP-000025';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00006', 'PO-2026-00005', 'EMP-000043', '65C-345.67', '2026-08-26 06:00:00', '2026-08-26 14:00:00');
SET @current_employee_id = 'EMP-000043';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00006';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-08-26 13:20:00', departure_temp = 2.0, arrival_temp = 3.0
 WHERE shipment_id = 'SHP-2026-00006';
SET @current_employee_id = 'EMP-000025';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00005';

-- ---- PO-2026-00006 : SUP-005 -> WH-FZ-03 [received]
SET @current_employee_id = 'EMP-000031';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00006', 'SUP-005', 'WH-FZ-03', 'EMP-000031', '2026-09-02', '2026-09-07');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00006', 'RM-000011', 500, 55000),
    ('PO-2026-00006', 'RM-000012', 100, 305000);
SET @current_employee_id = 'EMP-000016';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00006';
SET @current_employee_id = 'EMP-000031';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00007', 'PO-2026-00006', 'EMP-000044', '51D-678.90', '2026-09-03 06:00:00', '2026-09-03 14:00:00');
SET @current_employee_id = 'EMP-000044';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00007';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-09-03 13:20:00', departure_temp = -21.0, arrival_temp = -19.0
 WHERE shipment_id = 'SHP-2026-00007';
SET @current_employee_id = 'EMP-000031';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00006';

-- ---- PO-2026-00007 : SUP-001 -> WH-CL-01 [received]
SET @current_employee_id = 'EMP-000021';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00007', 'SUP-001', 'WH-CL-01', 'EMP-000021', '2026-09-08', '2026-09-13');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00007', 'RM-000005', 200, 150000),
    ('PO-2026-00007', 'RM-000003', 150, 98000);
SET @current_employee_id = 'EMP-000011';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00007';
SET @current_employee_id = 'EMP-000021';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00008', 'PO-2026-00007', 'EMP-000041', '29C-456.78', '2026-09-09 06:00:00', '2026-09-09 14:00:00');
SET @current_employee_id = 'EMP-000041';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00008';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-09-09 13:20:00', departure_temp = 2.0, arrival_temp = 3.0
 WHERE shipment_id = 'SHP-2026-00008';
SET @current_employee_id = 'EMP-000021';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00007';

-- ---- PO-2026-00008 : SUP-002 -> WH-FZ-02 [received]
SET @current_employee_id = 'EMP-000029';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00008', 'SUP-002', 'WH-FZ-02', 'EMP-000029', '2026-09-10', '2026-09-15');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00008', 'RM-000007', 300, 168000),
    ('PO-2026-00008', 'RM-000008', 250, 138000);
SET @current_employee_id = 'EMP-000015';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00008';
SET @current_employee_id = 'EMP-000029';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00009', 'PO-2026-00008', 'EMP-000042', '43D-789.01', '2026-09-11 06:00:00', '2026-09-11 14:00:00');
SET @current_employee_id = 'EMP-000042';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00009';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-09-11 13:20:00', departure_temp = -21.0, arrival_temp = -19.0
 WHERE shipment_id = 'SHP-2026-00009';
SET @current_employee_id = 'EMP-000029';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00008';

-- ---- PO-2026-00009 : SUP-003 -> WH-FZ-03 [breach_then_received]
SET @current_employee_id = 'EMP-000031';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00009', 'SUP-003', 'WH-FZ-03', 'EMP-000031', '2026-09-14', '2026-09-19');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00009', 'RM-000009', 700, 70000);
SET @current_employee_id = 'EMP-000016';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00009';
SET @current_employee_id = 'EMP-000031';
-- first shipment breaks the cold chain: trigger forces status Rejected (BR-SHP-09)
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00010', 'PO-2026-00009', 'EMP-000043', '15D-890.12', '2026-09-15 06:00:00', '2026-09-15 14:00:00');
SET @current_employee_id = 'EMP-000043';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00010';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-09-15 13:20:00', departure_temp = -20.0, arrival_temp = -12.0
 WHERE shipment_id = 'SHP-2026-00010';
SET @current_employee_id = 'EMP-000031';
-- re-delivery with a new shipment (BR-PO-10)
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00011', 'PO-2026-00009', 'EMP-000044', '51D-678.90', '2026-09-15 06:00:00', '2026-09-15 14:00:00');
SET @current_employee_id = 'EMP-000044';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00011';
UPDATE shipment SET status = 'Delivered', actual_arrival = '2026-09-15 13:20:00', departure_temp = -21.0, arrival_temp = -19.0
 WHERE shipment_id = 'SHP-2026-00011';
SET @current_employee_id = 'EMP-000031';
UPDATE purchase_order SET status = 'Received' WHERE po_id = 'PO-2026-00009';

-- ---- PO-2026-00010 : SUP-006 -> WH-CL-01 [in_transit]
SET @current_employee_id = 'EMP-000021';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00010', 'SUP-006', 'WH-CL-01', 'EMP-000021', '2026-09-28', '2026-10-03');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00010', 'RM-000006', 400, 69000),
    ('PO-2026-00010', 'RM-000003', 150, 96000);
SET @current_employee_id = 'EMP-000011';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00010';
SET @current_employee_id = 'EMP-000021';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00012', 'PO-2026-00010', 'EMP-000041', '51C-123.45', '2026-09-29 06:00:00', '2026-09-29 14:00:00');
SET @current_employee_id = 'EMP-000041';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00012';

-- ---- PO-2026-00011 : SUP-004 -> WH-CL-02 [confirmed_planned]
SET @current_employee_id = 'EMP-000023';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00011', 'SUP-004', 'WH-CL-02', 'EMP-000023', '2026-09-30', '2026-10-05');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00011', 'RM-000002', 250, 207000),
    ('PO-2026-00011', 'RM-000004', 100, 262000);
SET @current_employee_id = 'EMP-000012';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00011';
SET @current_employee_id = 'EMP-000023';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00013', 'PO-2026-00011', 'EMP-000042', '51C-234.56', '2026-10-01 06:00:00', '2026-10-01 14:00:00');

-- ---- PO-2026-00012 : SUP-005 -> WH-FZ-01 [cancel_in_transit]
SET @current_employee_id = 'EMP-000027';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00012', 'SUP-005', 'WH-FZ-01', 'EMP-000027', '2026-09-20', '2026-09-25');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00012', 'RM-000011', 300, 56000);
SET @current_employee_id = 'EMP-000014';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00012';
SET @current_employee_id = 'EMP-000027';
INSERT INTO shipment (shipment_id, po_id, driver_id, vehicle_plate, departure_time, est_arrival)
VALUES ('SHP-2026-00014', 'PO-2026-00012', 'EMP-000043', '43D-789.01', '2026-09-21 06:00:00', '2026-09-21 14:00:00');
SET @current_employee_id = 'EMP-000043';
UPDATE shipment SET status = 'In_Transit' WHERE shipment_id = 'SHP-2026-00014';
SET @current_employee_id = 'EMP-000014';
UPDATE purchase_order SET status = 'Cancelled' WHERE po_id = 'PO-2026-00012';

-- ---- PO-2026-00013 : SUP-001 -> WH-CL-03 [draft]
SET @current_employee_id = 'EMP-000025';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00013', 'SUP-001', 'WH-CL-03', 'EMP-000025', '2026-10-02', '2026-10-07');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00013', 'RM-000001', 300, 84000),
    ('PO-2026-00013', 'RM-000005', 200, 152000);

-- ---- PO-2026-00014 : SUP-002 -> WH-FZ-03 [cancel_confirmed]
SET @current_employee_id = 'EMP-000031';
INSERT INTO purchase_order (po_id, supplier_id, warehouse_id, created_by, order_date, expected_date)
VALUES ('PO-2026-00014', 'SUP-002', 'WH-FZ-03', 'EMP-000031', '2026-09-25', '2026-09-30');
INSERT INTO order_detail (po_id, product_id, quantity, unit_price)
VALUES
    ('PO-2026-00014', 'RM-000012', 80, 312000);
SET @current_employee_id = 'EMP-000016';   -- Warehouse_Manager xác nhận đơn (BR-EMP-05)
UPDATE purchase_order SET status = 'Confirmed' WHERE po_id = 'PO-2026-00014';
SET @current_employee_id = 'EMP-000031';
SET @current_employee_id = 'EMP-000016';
UPDATE purchase_order SET status = 'Cancelled' WHERE po_id = 'PO-2026-00014';

-- 10. PRODUCTION / ISSUE / TRANSFER movements
INSERT INTO stock_movement (
    warehouse_id, product_id, movement_type, quantity, employee_id, po_id, note
)
VALUES
    ('WH-FZ-01', 'RM-000007', 'Issue', 200, 'EMP-000027', NULL, 'Xuất nguyên liệu sản xuất lẩu hải sản'),
    ('WH-FZ-01', 'FG-000001', 'Production_In', 300, 'EMP-000027', NULL, 'Nhập thành phẩm lẩu hải sản'),
    ('WH-FZ-01', 'FG-000002', 'Issue', 100, 'EMP-000028', NULL, 'Xuất giao siêu thị'),
    ('WH-FZ-01', 'FG-000002', 'Transfer_Out', 150, 'EMP-000028', NULL, 'Chuyển kho sang WH-FZ-02'),
    ('WH-FZ-02', 'FG-000002', 'Transfer_In', 150, 'EMP-000029', NULL, 'Nhận chuyển kho từ WH-FZ-01'),
    ('WH-CL-01', 'RM-000001', 'Issue', 300, 'EMP-000022', NULL, 'Xuất nguyên liệu sản xuất sushi'),
    ('WH-CL-01', 'FG-000007', 'Production_In', 200, 'EMP-000022', NULL, 'Nhập thành phẩm sushi cá ngừ'),
    ('WH-CL-02', 'FG-000008', 'Adjust_Out', 20, 'EMP-000023', NULL, 'Điều chỉnh hao hụt kiểm kê');

-- 11. LOW-STOCK ALERT SCENARIOS (BR-INV-04, BR-ALT-02, BR-ALT-04)
-- (a) quantity <= reorder_level -> an Open alert is created
UPDATE inventory SET reorder_level = 5000 WHERE warehouse_id = 'WH-CL-02' AND product_id = 'RM-000004';
UPDATE inventory SET reorder_level = 4000 WHERE warehouse_id = 'WH-FZ-03' AND product_id = 'FG-000005';
UPDATE inventory SET reorder_level = 6000 WHERE warehouse_id = 'WH-CL-01' AND product_id = 'RM-000003';
-- (b) an alert that opens and is then resolved (history)
UPDATE inventory SET reorder_level = 99999 WHERE warehouse_id = 'WH-CL-03' AND product_id = 'RM-000005';
UPDATE inventory SET reorder_level = 100 WHERE warehouse_id = 'WH-CL-03' AND product_id = 'RM-000005';

-- =====================================================================
-- VERIFY (expected: warehouse 7, employee 24, supplier 8, product 20,
--         product_component 17, purchase_order 14, shipment 14)
-- =====================================================================
SELECT 'warehouse' AS table_name, COUNT(*) AS row_count FROM warehouse
UNION ALL SELECT 'employee', COUNT(*) FROM employee
UNION ALL SELECT 'supplier', COUNT(*) FROM supplier
UNION ALL SELECT 'supplier_certificate', COUNT(*) FROM supplier_certificate
UNION ALL SELECT 'product', COUNT(*) FROM product
UNION ALL SELECT 'product_component', COUNT(*) FROM product_component
UNION ALL SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL SELECT 'purchase_order', COUNT(*) FROM purchase_order
UNION ALL SELECT 'order_detail', COUNT(*) FROM order_detail
UNION ALL SELECT 'shipment', COUNT(*) FROM shipment
UNION ALL SELECT 'stock_movement', COUNT(*) FROM stock_movement
UNION ALL SELECT 'inventory_alert', COUNT(*) FROM inventory_alert
UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log;

SELECT status, COUNT(*) AS po_count FROM purchase_order GROUP BY status;
SELECT status, cold_chain_breach, COUNT(*) AS shipment_count FROM shipment GROUP BY status, cold_chain_breach;
