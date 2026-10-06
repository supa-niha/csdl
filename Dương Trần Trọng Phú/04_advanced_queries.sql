
USE cold_chain_db;
SET NAMES utf8mb4;
SET SESSION block_encryption_mode = 'aes-256-cbc';

-- Định mức hiện hành (BR-BOM-08): một tên duy nhất v_current_bom
CREATE OR REPLACE VIEW v_current_bom AS
SELECT pc.parent_product_id,
       pc.component_product_id,
       pc.effective_date,
       pc.quantity_required,
       pc.wastage_rate
  FROM product_component AS pc
 WHERE pc.effective_date = (
           SELECT MAX(pc2.effective_date)
             FROM product_component AS pc2
            WHERE pc2.parent_product_id = pc.parent_product_id
              AND pc2.component_product_id = pc.component_product_id
              AND pc2.effective_date <= CURDATE()
       );


-- =====================================================================
-- Q01  Stock cover per warehouse and product (3-table JOIN, CASE)
-- Question : which items are closest to their reorder level?   [FR-05]
-- =====================================================================
SELECT w.warehouse_id,
       w.warehouse_name,
       p.product_id,
       p.product_name,
       i.quantity,
       i.reorder_level,
       ROUND(i.quantity / NULLIF(i.reorder_level, 0), 2) AS cover_ratio,
       CASE
           WHEN i.quantity <= i.reorder_level THEN 'Cần nhập thêm'
           WHEN i.quantity <= i.reorder_level * 2 THEN 'Sắp hết'
           ELSE 'Đủ hàng'
       END AS stock_status
  FROM inventory AS i
  INNER JOIN warehouse AS w
      ON w.warehouse_id = i.warehouse_id
  INNER JOIN product AS p
      ON p.product_id = i.product_id
 ORDER BY cover_ratio ASC, w.warehouse_id, p.product_id
 LIMIT 15;


-- =====================================================================
-- Q02  Capacity utilisation per warehouse (JOIN, aggregation, HAVING)
-- Question : how full is each warehouse (volume used / capacity_m3)? [BR-WH-07]
-- =====================================================================
SELECT w.warehouse_id,
       w.warehouse_name,
       w.warehouse_type,
       w.capacity_m3,
       ROUND(SUM(i.quantity * p.volume_m3), 2) AS used_m3,
       ROUND(SUM(i.quantity * p.volume_m3) / w.capacity_m3 * 100, 2) AS used_percent
  FROM warehouse AS w
  INNER JOIN inventory AS i
      ON i.warehouse_id = w.warehouse_id
  INNER JOIN product AS p
      ON p.product_id = i.product_id
 GROUP BY w.warehouse_id, w.warehouse_name, w.warehouse_type, w.capacity_m3
HAVING SUM(i.quantity * p.volume_m3) > 0
 ORDER BY used_percent DESC;


-- =====================================================================
-- Q03  Network-wide stock vs reorder level (subquery in FROM)
-- Question : which products are low across ALL warehouses together?
-- =====================================================================
SELECT p.product_id,
       p.product_name,
       p.product_type,
       s.warehouse_count,
       s.total_quantity,
       s.total_reorder_level
  FROM product AS p
  INNER JOIN (
        SELECT product_id,
               COUNT(*)           AS warehouse_count,
               SUM(quantity)      AS total_quantity,
               SUM(reorder_level) AS total_reorder_level
          FROM inventory
         GROUP BY product_id
      ) AS s
      ON s.product_id = p.product_id
 WHERE s.total_quantity < s.total_reorder_level * 4
 ORDER BY s.total_quantity / NULLIF(s.total_reorder_level, 0);


-- =====================================================================
-- Q04  Monthly purchasing value per supplier (JOIN, GROUP BY, date format)
-- Question : how much do we buy from each supplier each month?
-- =====================================================================
SELECT DATE_FORMAT(po.order_date, '%Y-%m') AS order_month,
       s.supplier_id,
       s.supplier_name,
       COUNT(*)             AS order_count,
       SUM(po.total_amount) AS total_spend
  FROM purchase_order AS po
  INNER JOIN supplier AS s
      ON s.supplier_id = po.supplier_id
 WHERE po.status IN ('Confirmed', 'Shipping', 'Received')
 GROUP BY DATE_FORMAT(po.order_date, '%Y-%m'), s.supplier_id, s.supplier_name
 ORDER BY order_month, total_spend DESC;


-- =====================================================================
-- Q05  Cold-chain breach rate per supplier (4-table JOIN, conditional agg)
-- Question : which suppliers deliver goods that break the cold chain? [FR-11]
-- =====================================================================
SELECT s.supplier_id,
       s.supplier_name,
       COUNT(sh.shipment_id)                         AS finished_shipments,
       SUM(sh.cold_chain_breach)                     AS breach_count,
       ROUND(100 * SUM(sh.cold_chain_breach) / COUNT(sh.shipment_id), 1) AS breach_percent
  FROM supplier AS s
  INNER JOIN purchase_order AS po
      ON po.supplier_id = s.supplier_id
  INNER JOIN shipment AS sh
      ON sh.po_id = po.po_id
 WHERE sh.status IN ('Delivered', 'Rejected')
 GROUP BY s.supplier_id, s.supplier_name
 ORDER BY breach_percent DESC, finished_shipments DESC;


-- =====================================================================
-- Q06  Bill-of-materials explosion (recursive CTE)
-- Question : what raw materials, at every level, make 1 unit of
--            finished good FG-000006 (including wastage)?   [FR-03]
-- =====================================================================
WITH RECURSIVE bom_tree (level_no, product_id, qty_per_unit, path) AS (
    SELECT 1,
           b.component_product_id,
           CAST(b.quantity_required * (1 + b.wastage_rate / 100) AS DECIMAL(20,6)),
           CAST(CONCAT(b.parent_product_id, ' > ', b.component_product_id) AS CHAR(500))
      FROM v_current_bom AS b
     WHERE b.parent_product_id = 'FG-000006'
    UNION ALL
    SELECT bt.level_no + 1,
           b.component_product_id,
           CAST(bt.qty_per_unit * b.quantity_required * (1 + b.wastage_rate / 100) AS DECIMAL(20,6)),
           CAST(CONCAT(bt.path, ' > ', b.component_product_id) AS CHAR(500))
      FROM bom_tree AS bt
      INNER JOIN v_current_bom AS b
          ON b.parent_product_id = bt.product_id
)
SELECT bt.level_no,
       bt.product_id,
       p.product_name,
       p.product_type,
       ROUND(bt.qty_per_unit, 3) AS qty_per_unit,
       bt.path
  FROM bom_tree AS bt
  INNER JOIN product AS p
      ON p.product_id = bt.product_id
 ORDER BY bt.level_no, bt.product_id;


-- =====================================================================
-- Q07  Reverse traceability [FR-14, NFR-02]
-- =====================================================================
WITH RECURSIVE bom_leaf (product_id) AS (
    SELECT b.component_product_id
      FROM v_current_bom AS b
     WHERE b.parent_product_id = 'FG-000001'
    UNION
    SELECT b.component_product_id
      FROM bom_leaf AS bl
      INNER JOIN v_current_bom AS b
          ON b.parent_product_id = bl.product_id
)
SELECT rm.product_id   AS raw_material_id,
       rm.product_name AS raw_material_name,
       po.po_id,
       po.order_date,
       s.supplier_id,
       s.supplier_name,
       od.quantity,
       od.unit_price
  FROM bom_leaf AS bl
  INNER JOIN product AS rm
      ON rm.product_id = bl.product_id
     AND rm.product_type = 'RAW_MATERIAL'
  INNER JOIN order_detail AS od
      ON od.product_id = rm.product_id
  INNER JOIN purchase_order AS po
      ON po.po_id = od.po_id
     AND po.status = 'Received'
  INNER JOIN supplier AS s
      ON s.supplier_id = po.supplier_id
 ORDER BY rm.product_id, po.order_date;


-- =====================================================================
-- Q08  Supplier ranking inside each supplier type (window RANK)
-- =====================================================================
SELECT t.supplier_type,
       t.supplier_id,
       t.supplier_name,
       t.total_spend,
       RANK() OVER (PARTITION BY t.supplier_type ORDER BY t.total_spend DESC) AS spend_rank
  FROM (
        SELECT s.supplier_id,
               s.supplier_name,
               s.supplier_type,
               COALESCE(SUM(po.total_amount), 0) AS total_spend
          FROM supplier AS s
          LEFT JOIN purchase_order AS po
              ON po.supplier_id = s.supplier_id
             AND po.status = 'Received'
         GROUP BY s.supplier_id, s.supplier_name, s.supplier_type
      ) AS t
 ORDER BY t.supplier_type, spend_rank, t.supplier_id;


-- =====================================================================
-- Q09  Orders above their warehouse average (correlated subquery)
-- =====================================================================
SELECT po.po_id,
       po.warehouse_id,
       po.order_date,
       po.status,
       po.total_amount,
       ROUND((
           SELECT AVG(po2.total_amount)
             FROM purchase_order AS po2
            WHERE po2.warehouse_id = po.warehouse_id
              AND po2.status <> 'Cancelled'
       ), 2) AS warehouse_avg
  FROM purchase_order AS po
 WHERE po.status <> 'Cancelled'
   AND po.total_amount > (
           SELECT AVG(po2.total_amount)
             FROM purchase_order AS po2
            WHERE po2.warehouse_id = po.warehouse_id
              AND po2.status <> 'Cancelled'
       )
 ORDER BY po.warehouse_id, po.total_amount DESC;


-- =====================================================================
-- Q10  Staff activity by movement type (pivot CASE SUM) [FR-04, NFR-05]
-- =====================================================================
SELECT e.employee_id,
       e.full_name,
       e.warehouse_id,
       COUNT(*) AS movement_count,
       SUM(CASE WHEN sm.movement_type = 'Receipt' THEN sm.quantity ELSE 0 END)       AS received_qty,
       SUM(CASE WHEN sm.movement_type = 'Issue' THEN sm.quantity ELSE 0 END)         AS issued_qty,
       SUM(CASE WHEN sm.movement_type = 'Production_In' THEN sm.quantity ELSE 0 END) AS produced_qty,
       SUM(CASE WHEN sm.movement_type IN ('Transfer_In', 'Transfer_Out')
                THEN sm.quantity ELSE 0 END)                                         AS transferred_qty
  FROM stock_movement AS sm
  INNER JOIN employee AS e
      ON e.employee_id = sm.employee_id
 GROUP BY e.employee_id, e.full_name, e.warehouse_id
HAVING COUNT(*) >= 2
 ORDER BY movement_count DESC, e.employee_id;


-- =====================================================================
-- Q11  Certificate risk [BR-SUP-06]
-- =====================================================================
SELECT s.supplier_id,
       s.supplier_name,
       s.is_active,
       MAX(c.cert_expiry_date)                      AS latest_expiry,
       DATEDIFF(MAX(c.cert_expiry_date), CURDATE()) AS days_left,
       COUNT(DISTINCT po.po_id)                     AS open_orders
  FROM supplier AS s
  LEFT JOIN supplier_certificate AS c
      ON c.supplier_id = s.supplier_id
  LEFT JOIN purchase_order AS po
      ON po.supplier_id = s.supplier_id
     AND po.status IN ('Draft', 'Confirmed', 'Shipping')
 GROUP BY s.supplier_id, s.supplier_name, s.is_active
HAVING MAX(c.cert_expiry_date) IS NULL
    OR MAX(c.cert_expiry_date) < DATE_ADD(CURDATE(), INTERVAL 90 DAY)
 ORDER BY days_left;


-- =====================================================================
-- Q12  Warehouses ranked by open alerts [FR-05]
-- =====================================================================
SELECT w.warehouse_id,
       w.warehouse_name,
       COUNT(a.alert_id) AS open_alerts,
       COUNT(DISTINCT i.product_id) AS stocked_products
  FROM warehouse AS w
  LEFT JOIN inventory AS i
      ON i.warehouse_id = w.warehouse_id
  LEFT JOIN inventory_alert AS a
      ON a.warehouse_id = i.warehouse_id
     AND a.product_id = i.product_id
     AND a.status = 'Open'
 GROUP BY w.warehouse_id, w.warehouse_name
 ORDER BY open_alerts DESC, w.warehouse_id;


-- =====================================================================
-- Q13  Transit time by vehicle type
-- =====================================================================
SELECT v.vehicle_type,
       COUNT(*) AS delivered_shipments,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, sh.departure_time, sh.actual_arrival)) / 60, 2)
           AS avg_transit_hours,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, sh.est_arrival, sh.actual_arrival)), 1)
           AS avg_minutes_vs_estimate
  FROM shipment AS sh
  INNER JOIN vehicle AS v
      ON v.vehicle_plate = sh.vehicle_plate
 WHERE sh.status = 'Delivered'
   AND sh.actual_arrival IS NOT NULL
 GROUP BY v.vehicle_type;


-- =====================================================================
-- Q14  Full status history of one order and its shipments [FR-15]
-- =====================================================================
SELECT a.changed_at,
       a.table_name,
       a.record_key,
       a.action,
       a.old_value,
       a.new_value,
       COALESCE(e.full_name, '(hệ thống)') AS performed_by
  FROM audit_log AS a
  LEFT JOIN employee AS e
      ON e.employee_id = a.employee_id
 WHERE (a.table_name = 'PURCHASE_ORDER' AND a.record_key = 'PO-2026-00003')
    OR (a.table_name = 'SHIPMENT'
        AND a.record_key IN (
                SELECT shipment_id
                  FROM shipment
                 WHERE po_id = 'PO-2026-00003'
            ))
 ORDER BY a.changed_at, a.log_id;


-- =====================================================================
-- Q15  Stock ledger with running balance [NFR-05]
-- =====================================================================
SELECT l.movement_id,
       l.movement_time,
       l.movement_type,
       l.quantity,
       l.running_balance,
       i.quantity AS inventory_quantity
  FROM (
        SELECT sm.movement_id,
               sm.warehouse_id,
               sm.product_id,
               sm.movement_time,
               sm.movement_type,
               sm.quantity,
               SUM(CASE
                       WHEN sm.movement_type IN (
                           'Receipt', 'Production_In', 'Transfer_In', 'Adjust_In')
                           THEN sm.quantity
                       ELSE -sm.quantity
                   END) OVER (
                       PARTITION BY sm.warehouse_id, sm.product_id
                       ORDER BY sm.movement_id
                   ) AS running_balance
          FROM stock_movement AS sm
         WHERE sm.warehouse_id = 'WH-FZ-01'
           AND sm.product_id = 'RM-000007'
      ) AS l
  INNER JOIN inventory AS i
      ON i.warehouse_id = l.warehouse_id
     AND i.product_id = l.product_id
 ORDER BY l.movement_id;
-- The last running_balance must equal inventory_quantity.


-- =====================================================================
-- Q16  Decrypt employee phone (procedure) [NFR-04]
-- Requires: sp_get_employee_phone created by 02_logic.sql
-- =====================================================================
SET @aes_key = 'Eternal@PTIT2026';  -- demo key only
CALL sp_get_employee_phone('EMP-000011', @aes_key);


-- =====================================================================
-- PERFORMANCE TESTS (NFR-01 / NFR-02)
-- Index names MUST match 01_ddl_cold_chain_logistics.sql:
--   idx_order_detail_product
--   idx_po_supplier_date
--   idx_stockmv_wh_prod_time
-- =====================================================================

-- P1  inventory lookup by composite PK  [NFR-01]
EXPLAIN ANALYZE
SELECT quantity, reorder_level
  FROM inventory
 WHERE warehouse_id = 'WH-CL-01'
   AND product_id = 'RM-000001';

-- P2a without product index
EXPLAIN ANALYZE
SELECT od.po_id, od.quantity
  FROM order_detail AS od IGNORE INDEX (idx_order_detail_product)
 WHERE od.product_id = 'RM-000007';

-- P2b with idx_order_detail_product
EXPLAIN ANALYZE
SELECT od.po_id, od.quantity
  FROM order_detail AS od FORCE INDEX (idx_order_detail_product)
 WHERE od.product_id = 'RM-000007';

-- P3a without composite supplier+date index
EXPLAIN ANALYZE
SELECT po_id, order_date, total_amount
  FROM purchase_order IGNORE INDEX (idx_po_supplier_date)
 WHERE supplier_id = 'SUP-001'
   AND order_date BETWEEN '2026-08-01' AND '2026-09-30';

-- P3b with idx_po_supplier_date
EXPLAIN ANALYZE
SELECT po_id, order_date, total_amount
  FROM purchase_order FORCE INDEX (idx_po_supplier_date)
 WHERE supplier_id = 'SUP-001'
   AND order_date BETWEEN '2026-08-01' AND '2026-09-30';

-- P4  stock history  [idx_stockmv_wh_prod_time]
EXPLAIN ANALYZE
SELECT movement_id, movement_time, movement_type, quantity
  FROM stock_movement FORCE INDEX (idx_stockmv_wh_prod_time)
 WHERE warehouse_id = 'WH-FZ-01'
   AND product_id = 'RM-000007'
   AND movement_time >= '2026-01-01'
 ORDER BY movement_time;
