DROP DATABASE IF EXISTS cold_chain_db;
CREATE DATABASE cold_chain_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE cold_chain_db;
SET NAMES utf8mb4;

CREATE TABLE warehouse (
    warehouse_id    VARCHAR(10)   NOT NULL,
    warehouse_name  VARCHAR(100)  NOT NULL,
    address         VARCHAR(255)  NOT NULL,
    city            VARCHAR(50)   NOT NULL,
    country         VARCHAR(50)   NOT NULL,
    phone           VARCHAR(15)   NULL,
    warehouse_type  VARCHAR(20)   NOT NULL,
    area_m2         DECIMAL(10,2) NOT NULL,
    capacity_m3     DECIMAL(12,2) NOT NULL,
    storage_temp    DECIMAL(4,1)  NOT NULL,
    manager_id      VARCHAR(10)   NULL,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_warehouse PRIMARY KEY (warehouse_id),
    CONSTRAINT uq_warehouse_manager UNIQUE (manager_id),
    CONSTRAINT ck_warehouse_id_format
        CHECK (warehouse_id REGEXP '^WH-(CL|FZ)-[0-9]{2}$'),
    CONSTRAINT ck_warehouse_type
        CHECK (warehouse_type IN ('Cold', 'Frozen')),
    CONSTRAINT ck_warehouse_id_type
        CHECK ((warehouse_type = 'Cold'   AND warehouse_id LIKE 'WH-CL-%')
            OR (warehouse_type = 'Frozen' AND warehouse_id LIKE 'WH-FZ-%')),
    CONSTRAINT ck_warehouse_area_pos     CHECK (area_m2 > 0),
    CONSTRAINT ck_warehouse_capacity_pos CHECK (capacity_m3 > 0),
    CONSTRAINT ck_warehouse_temp
        CHECK ((warehouse_type = 'Cold'   AND storage_temp BETWEEN 0 AND 4)
            OR (warehouse_type = 'Frozen' AND storage_temp <= -18))
) ENGINE = InnoDB;


CREATE TABLE employee (
    employee_id   VARCHAR(10)  NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    phone         VARBINARY(64) NOT NULL,
    role          VARCHAR(30)  NOT NULL,
    warehouse_id  VARCHAR(10)  NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_employee PRIMARY KEY (employee_id),
    CONSTRAINT fk_employee_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouse (warehouse_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_employee_id_format
        CHECK (employee_id REGEXP '^EMP-[0-9]{6}$'),
    CONSTRAINT ck_employee_role
        CHECK (role IN ('Admin', 'Warehouse_Manager', 'Warehouse_Staff', 'Driver')),
    CONSTRAINT ck_employee_role_warehouse
        CHECK ((role IN ('Warehouse_Manager', 'Warehouse_Staff') AND warehouse_id IS NOT NULL)
            OR (role = 'Driver' AND warehouse_id IS NULL)
            OR  role = 'Admin')
) ENGINE = InnoDB;

-- Khóa ngoại vòng warehouse.manager_id -> employee (tạo sau để phá vòng phụ thuộc)
ALTER TABLE warehouse
    ADD CONSTRAINT fk_warehouse_manager FOREIGN KEY (manager_id)
        REFERENCES employee (employee_id)
        ON DELETE SET NULL ON UPDATE CASCADE;


CREATE TABLE supplier (
    supplier_id    VARCHAR(10)  NOT NULL,
    supplier_name  VARCHAR(100) NOT NULL,
    supplier_type  VARCHAR(20)  NOT NULL,
    contact_name   VARCHAR(100) NULL,
    phone          VARCHAR(15)  NOT NULL,
    email          VARCHAR(100) NULL,
    address        VARCHAR(255) NOT NULL,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_supplier PRIMARY KEY (supplier_id),
    CONSTRAINT uq_supplier_email UNIQUE (email),
    CONSTRAINT ck_supplier_id_format
        CHECK (supplier_id REGEXP '^SUP-[0-9]{3}$'),
    CONSTRAINT ck_supplier_type
        CHECK (supplier_type IN ('Fishing_Vessel', 'Trading_Agent', 'Importer'))
) ENGINE = InnoDB;

CREATE TABLE supplier_certificate (
    cert_number       VARCHAR(50) NOT NULL,
    supplier_id       VARCHAR(10) NOT NULL,
    cert_expiry_date  DATE        NOT NULL,
    CONSTRAINT pk_supplier_certificate PRIMARY KEY (cert_number),
    CONSTRAINT fk_cert_supplier FOREIGN KEY (supplier_id)
        REFERENCES supplier (supplier_id)
        ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB;


CREATE TABLE product (
    product_id    VARCHAR(10)   NOT NULL,
    product_code  VARCHAR(20)   NOT NULL,
    product_name  VARCHAR(100)  NOT NULL,
    product_type  VARCHAR(20)   NOT NULL,
    storage_type  VARCHAR(20)   NOT NULL,
    storage_temp  DECIMAL(4,1)  NOT NULL,
    unit          VARCHAR(10)   NOT NULL DEFAULT '',
    weight_kg     DECIMAL(10,3) NOT NULL,
    volume_m3     DECIMAL(10,3) NOT NULL,
    status        VARCHAR(20)   NOT NULL DEFAULT 'Draft',
    CONSTRAINT pk_product PRIMARY KEY (product_id),
    CONSTRAINT uq_product_code UNIQUE (product_code),
    CONSTRAINT ck_product_id_format
        CHECK ((product_type = 'RAW_MATERIAL'  AND product_id REGEXP '^RM-[0-9]{6}$')
            OR (product_type = 'FINISHED_GOOD' AND product_id REGEXP '^FG-[0-9]{6}$')),
    CONSTRAINT ck_product_storage_type
        CHECK (storage_type IN ('Chilled', 'Frozen')),
    CONSTRAINT ck_product_temp
        CHECK ((storage_type = 'Chilled' AND storage_temp BETWEEN 0 AND 4)
            OR (storage_type = 'Frozen'  AND storage_temp <= -18)),
    CONSTRAINT ck_product_unit_nonempty CHECK (unit <> ''),
    CONSTRAINT ck_product_weight_pos    CHECK (weight_kg > 0),
    CONSTRAINT ck_product_volume_pos    CHECK (volume_m3 > 0),
    CONSTRAINT ck_product_status
        CHECK (status IN ('Draft', 'Active', 'Discontinued', 'Archived'))
) ENGINE = InnoDB;

CREATE TABLE raw_material (
    product_id           VARCHAR(10)  NOT NULL,
    default_supplier_id  VARCHAR(10)  NULL,
    expiry_days          INT          NOT NULL,
    catch_area           VARCHAR(100) NOT NULL,
    CONSTRAINT pk_raw_material PRIMARY KEY (product_id),
    CONSTRAINT fk_raw_material_product FOREIGN KEY (product_id)
        REFERENCES product (product_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_raw_material_supplier FOREIGN KEY (default_supplier_id)
        REFERENCES supplier (supplier_id)
        ON DELETE SET NULL ON UPDATE RESTRICT,
    CONSTRAINT ck_raw_material_expiry_pos CHECK (expiry_days > 0)
) ENGINE = InnoDB;

CREATE TABLE finished_good (
    product_id     VARCHAR(10)  NOT NULL,
    expiry_months  INT          NOT NULL,
    package_spec   VARCHAR(100) NOT NULL,
    CONSTRAINT pk_finished_good PRIMARY KEY (product_id),
    CONSTRAINT fk_finished_good_product FOREIGN KEY (product_id)
        REFERENCES product (product_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT ck_finished_good_expiry_pos CHECK (expiry_months > 0)
) ENGINE = InnoDB;


  
CREATE TABLE product_component (
    parent_product_id     VARCHAR(10)   NOT NULL,
    component_product_id  VARCHAR(10)   NOT NULL,
    effective_date        DATE          NOT NULL,
    quantity_required     DECIMAL(10,3) NOT NULL,
    wastage_rate          DECIMAL(5,2)  NOT NULL DEFAULT 0,
    CONSTRAINT pk_product_component
        PRIMARY KEY (parent_product_id, component_product_id, effective_date),
    CONSTRAINT fk_bom_parent FOREIGN KEY (parent_product_id)
        REFERENCES product (product_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_bom_component FOREIGN KEY (component_product_id)
        REFERENCES product (product_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_bom_not_self      CHECK (parent_product_id <> component_product_id),
    CONSTRAINT ck_bom_quantity_pos  CHECK (quantity_required > 0),
    CONSTRAINT ck_bom_wastage_range CHECK (wastage_rate BETWEEN 0 AND 100)
) ENGINE = InnoDB;


CREATE TABLE inventory (
    warehouse_id       VARCHAR(10)   NOT NULL,
    product_id         VARCHAR(10)   NOT NULL,
    quantity           DECIMAL(12,3) NOT NULL DEFAULT 0,
    reorder_level      DECIMAL(12,3) NOT NULL DEFAULT 0,
    max_capacity       DECIMAL(12,3) NULL,
    last_updated       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_restock_date  DATE          NULL,
    notes              TEXT          NULL,
    CONSTRAINT pk_inventory PRIMARY KEY (warehouse_id, product_id),
    CONSTRAINT fk_inventory_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouse (warehouse_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id)
        REFERENCES product (product_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_inventory_quantity_nonneg CHECK (quantity >= 0),
    CONSTRAINT ck_inventory_reorder_nonneg  CHECK (reorder_level >= 0),
    CONSTRAINT ck_inventory_max_capacity
        CHECK (max_capacity IS NULL OR quantity <= max_capacity)
) ENGINE = InnoDB;



CREATE TABLE purchase_order (
    po_id          VARCHAR(15)   NOT NULL,
    supplier_id    VARCHAR(10)   NOT NULL,
    warehouse_id   VARCHAR(10)   NOT NULL,
    created_by     VARCHAR(10)   NOT NULL,
    status         VARCHAR(20)   NOT NULL DEFAULT 'Draft',
    order_date     DATE          NOT NULL DEFAULT (CURDATE()),
    expected_date  DATE          NULL,
    total_amount   DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT pk_purchase_order PRIMARY KEY (po_id),
    CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id)
        REFERENCES supplier (supplier_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_po_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouse (warehouse_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_po_employee FOREIGN KEY (created_by)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_po_id_format
        CHECK (po_id REGEXP '^PO-[0-9]{4}-[0-9]{5}$'),
    CONSTRAINT ck_po_status
        CHECK (status IN ('Draft', 'Confirmed', 'Shipping', 'Received', 'Cancelled')),
    CONSTRAINT ck_po_expected_date
        CHECK (expected_date IS NULL OR expected_date >= order_date),
    CONSTRAINT ck_po_total_nonneg CHECK (total_amount >= 0)
) ENGINE = InnoDB;

CREATE TABLE order_detail (
    po_id          VARCHAR(15)   NOT NULL,
    product_id     VARCHAR(10)   NOT NULL,
    quantity       DECIMAL(12,3) NOT NULL,
    unit_price     DECIMAL(12,2) NOT NULL,
    required_temp  DECIMAL(4,1)  NOT NULL,
    CONSTRAINT pk_order_detail PRIMARY KEY (po_id, product_id),
    CONSTRAINT fk_od_po FOREIGN KEY (po_id)
        REFERENCES purchase_order (po_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_od_product FOREIGN KEY (product_id)
        REFERENCES product (product_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_od_quantity_pos     CHECK (quantity > 0),
    CONSTRAINT ck_od_unit_price_nonneg CHECK (unit_price >= 0),
    CONSTRAINT ck_od_required_temp
        CHECK (required_temp BETWEEN 0 AND 4 OR required_temp <= -18)
) ENGINE = InnoDB;


 
CREATE TABLE vehicle (
    vehicle_plate  VARCHAR(15) NOT NULL,
    vehicle_type   VARCHAR(50) NOT NULL,
    CONSTRAINT pk_vehicle PRIMARY KEY (vehicle_plate),
    CONSTRAINT ck_vehicle_type
        CHECK (vehicle_type IN ('Reefer_Truck', 'Freezer_Container'))
) ENGINE = InnoDB;

CREATE TABLE shipment (
    shipment_id        VARCHAR(15)  NOT NULL,
    po_id              VARCHAR(15)  NOT NULL,
    driver_id          VARCHAR(10)  NOT NULL,
    vehicle_plate      VARCHAR(15)  NOT NULL,
    departure_time     DATETIME     NULL,
    est_arrival        DATETIME     NOT NULL,
    actual_arrival     DATETIME     NULL,
    departure_temp     DECIMAL(4,1) NULL,
    arrival_temp       DECIMAL(4,1) NULL,
    cold_chain_breach  BOOLEAN      NOT NULL DEFAULT FALSE,
    status             VARCHAR(20)  NOT NULL DEFAULT 'Planned',
    CONSTRAINT pk_shipment PRIMARY KEY (shipment_id),
    CONSTRAINT fk_shipment_po FOREIGN KEY (po_id)
        REFERENCES purchase_order (po_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_shipment_driver FOREIGN KEY (driver_id)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_shipment_vehicle FOREIGN KEY (vehicle_plate)
        REFERENCES vehicle (vehicle_plate)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_shipment_id_format
        CHECK (shipment_id REGEXP '^SHP-[0-9]{4}-[0-9]{5}$'),
    CONSTRAINT ck_shipment_status
        CHECK (status IN ('Planned', 'In_Transit', 'Delivered', 'Rejected')),
    CONSTRAINT ck_shipment_arrival_after_departure
        CHECK (actual_arrival IS NULL OR departure_time IS NULL
               OR actual_arrival >= departure_time),
    CONSTRAINT ck_shipment_temp_sane
        CHECK ((departure_temp IS NULL OR departure_temp BETWEEN -60 AND 40)
           AND (arrival_temp   IS NULL OR arrival_temp   BETWEEN -60 AND 40)),
    CONSTRAINT ck_shipment_delivered_complete
        CHECK (status <> 'Delivered'
               OR (departure_temp IS NOT NULL AND arrival_temp IS NOT NULL
                   AND actual_arrival IS NOT NULL))
) ENGINE = InnoDB;

 
CREATE TABLE stock_movement (
    movement_id    BIGINT        NOT NULL AUTO_INCREMENT,
    warehouse_id   VARCHAR(10)   NOT NULL,
    product_id     VARCHAR(10)   NOT NULL,
    movement_type  VARCHAR(20)   NOT NULL,
    quantity       DECIMAL(12,3) NOT NULL,
    movement_time  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    employee_id    VARCHAR(10)   NOT NULL,
    po_id          VARCHAR(15)   NULL,
    note           VARCHAR(255)  NULL,
    CONSTRAINT pk_stock_movement PRIMARY KEY (movement_id),
    CONSTRAINT fk_stockmv_warehouse FOREIGN KEY (warehouse_id)
        REFERENCES warehouse (warehouse_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_stockmv_product FOREIGN KEY (product_id)
        REFERENCES product (product_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_stockmv_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_stockmv_po FOREIGN KEY (po_id)
        REFERENCES purchase_order (po_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_stockmv_type
        CHECK (movement_type IN ('Receipt', 'Production_In', 'Transfer_In', 'Adjust_In',
                                 'Issue', 'Transfer_Out', 'Adjust_Out')),
    CONSTRAINT ck_stockmv_quantity_pos CHECK (quantity > 0),
    CONSTRAINT ck_stockmv_receipt_po
        CHECK ((movement_type = 'Receipt' AND po_id IS NOT NULL)
            OR (movement_type <> 'Receipt' AND po_id IS NULL))
) ENGINE = InnoDB;

CREATE TABLE inventory_alert (
    alert_id                BIGINT        NOT NULL AUTO_INCREMENT,
    warehouse_id            VARCHAR(10)   NOT NULL,
    product_id              VARCHAR(10)   NOT NULL,
    quantity_at_alert       DECIMAL(12,3) NOT NULL,
    reorder_level_at_alert  DECIMAL(12,3) NOT NULL,
    status                  VARCHAR(10)   NOT NULL DEFAULT 'Open',
    created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at             DATETIME      NULL,
    CONSTRAINT pk_inventory_alert PRIMARY KEY (alert_id),
    CONSTRAINT fk_alert_inventory FOREIGN KEY (warehouse_id, product_id)
        REFERENCES inventory (warehouse_id, product_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_alert_quantity_nonneg CHECK (quantity_at_alert >= 0),
    CONSTRAINT ck_alert_reorder_nonneg  CHECK (reorder_level_at_alert >= 0),
    CONSTRAINT ck_alert_status CHECK (status IN ('Open', 'Resolved')),
    CONSTRAINT ck_alert_resolved_consistent
        CHECK ((status = 'Open'     AND resolved_at IS NULL)
            OR (status = 'Resolved' AND resolved_at IS NOT NULL))
) ENGINE = InnoDB;

CREATE TABLE audit_log (
    log_id       BIGINT       NOT NULL AUTO_INCREMENT,
    table_name   VARCHAR(30)  NOT NULL,
    record_key   VARCHAR(50)  NOT NULL,
    action       VARCHAR(20)  NOT NULL,
    old_value    VARCHAR(20)  NULL,
    new_value    VARCHAR(20)  NOT NULL,
    employee_id  VARCHAR(10)  NULL,
    changed_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_audit_log PRIMARY KEY (log_id),
    CONSTRAINT fk_audit_employee FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_audit_table  CHECK (table_name IN ('PURCHASE_ORDER', 'SHIPMENT')),
    CONSTRAINT ck_audit_action CHECK (action IN ('CREATE', 'STATUS_CHANGE')),
    CONSTRAINT ck_audit_old_value
        CHECK ((action = 'CREATE' AND old_value IS NULL)
            OR (action = 'STATUS_CHANGE' AND old_value IS NOT NULL))
) ENGINE = InnoDB;

 
CREATE INDEX idx_po_supplier_date      ON purchase_order (supplier_id, order_date);
CREATE INDEX idx_po_status_date        ON purchase_order (status, order_date);
CREATE INDEX idx_po_warehouse_status   ON purchase_order (warehouse_id, status);
CREATE INDEX idx_shipment_status_est   ON shipment (status, est_arrival);
CREATE INDEX idx_shipment_driver       ON shipment (driver_id, status);
CREATE INDEX idx_stockmv_wh_prod_time  ON stock_movement (warehouse_id, product_id, movement_time);
CREATE INDEX idx_alert_pair_status     ON inventory_alert (warehouse_id, product_id, status);
CREATE INDEX idx_alert_status_created  ON inventory_alert (status, created_at);
CREATE INDEX idx_audit_record          ON audit_log (table_name, record_key, changed_at);
CREATE INDEX idx_product_type_status   ON product (product_type, status);
CREATE INDEX idx_product_name          ON product (product_name);
CREATE INDEX idx_order_detail_product  ON order_detail (product_id);
CREATE INDEX idx_cert_supplier_expiry  ON supplier_certificate (supplier_id, cert_expiry_date);
