**BẢNG PHÂN CÔNG CÔNG VIỆC NHÓM**

_Team Eternal · INT1313 · Supply Chain & Warehouse Logistics Network_

Thành viên: Nguyễn Thành Nguyên · Dương Trần Trọng Phú · Mai Gia Phúc

## Phase 1 – Phân tích và thiết kế khái niệm

| **Việc**                                                | **Sản phẩm**        | **Làm chính** | **Hỗ trợ** |
| ------------------------------------------------------- | ------------------- | ------------- | ---------- |
| Mô tả bài toán, phạm vi, đối tượng khảo sát             | Báo cáo mục 1.1–1.2 | Nguyên        | Phú        |
| Viết 15 yêu cầu chức năng                               | Mục 1.3             | Nguyên        | Phú        |
| Viết 10 yêu cầu phi chức năng (hiệu năng, mã hóa, ACID) | Mục 1.4             | Phúc          | Nguyên     |
| Soạn 106 quy tắc nghiệp vụ nhóm A–K                     | Mục 1.5             | Phúc          | Nguyên     |
| Chọn nền tảng, quy ước đặt tên                          | Mục 1.6             | Phú           | —          |

## Phase 2 – Thiết kế logic và chuẩn hóa

| **Việc**                                                                     | **Sản phẩm**       | **Làm chính** | **Hỗ trợ** |
| ---------------------------------------------------------------------------- | ------------------ | ------------- | ---------- |
| Vẽ sơ đồ EER (Crow's Foot), chuyên biệt hóa Product                          | Mục 2.1, Phụ lục A | Nguyên        | —          |
| Ánh xạ EER sang 16 quan hệ, lập bảng khóa ngoại                              | Mục 2.2            | Nguyên        | Phúc       |
| Chứng minh BCNF; tách SHIPMENT/VEHICLE, SUPPLIER/CERTIFICATE (lossless-join) | Mục 2.3            | Nguyên        | —          |
| Phi chuẩn hóa có chủ đích (total_amount, cold_chain_breach, required_temp)   | Mục 2.3            | Phúc          | —          |
| Từ điển dữ liệu 16 bảng                                                      | Mục 3              | Phúc          | Phú        |

## Phase 3 – Cài đặt và truy vấn

| **Việc**                                              | **Sản phẩm**                      | **Làm chính** | **Hỗ trợ** |
| ----------------------------------------------------- | --------------------------------- | ------------- | ---------- |
| Viết DDL: bảng, khóa, CHECK, index                    | 01_schema.sql, mục 4.1            | Phúc          | Nguyên     |
| Viết function, procedure (chuỗi lạnh, mã hóa AES)     | 02_logic.sql, mục 4.2             | Phúc          | Phú        |
| Viết trigger kiểm tra quy tắc và nhật ký kiểm toán    | 02_logic.sql, mục 4.2             | Phúc          | —          |
| Viết view (tồn thấp, mức dùng kho, truy xuất)         | 02_logic.sql                      | Phú           | Phúc       |
| Soạn dữ liệu mẫu đi qua trigger                       | 03_dml_sample_data.sql, mục 4.3   | Phúc          | Phú        |
| Truy vấn Q01–Q08 (JOIN, GROUP BY, CTE đệ quy, window) | 04_advanced_queries.sql           | Phúc          | —          |
| Truy vấn Q09–Q16 (subquery, pivot, ledger, giải mã)   | 04_advanced_queries.sql           | Phú           | Phúc       |
| Sinh dữ liệu lớn, đo EXPLAIN ANALYZE P1–P4            | 07_bulk_data.sql, mục 4.4.1–4.4.2 | Phú           | Phúc       |
| Checklist chất lượng SQL, thứ tự chạy                 | Mục 4.5–4.6                       | Nguyên        | —          |

## Phase 4 – Tích hợp, bảo mật và bảo vệ

| **Việc**                                            | **Sản phẩm**               | **Làm chính** | **Hỗ trợ** |
| --------------------------------------------------- | -------------------------- | ------------- | ---------- |
| Xây ứng dụng Flask (route, kết nối, dịch lỗi)       | app.py, db.py, templates   | Phú           | —          |
| Tạo tài khoản app_user quyền tối thiểu              | 05_app_user.sql, mục 5.2.1 | Phú           | —          |
| Tạo role và tài khoản RBAC, REVOKE                  | 06_rbac.sql, mục 5.2.2     | Phú           | Phúc       |
| Chạy test T1–T11, chụp ảnh                          | Mục 5.1 bảng A             | Phú           | Phúc       |
| Chạy test R1–R8, chụp ảnh                           | Mục 5.1 bảng B             | Phú           | —          |
| Viết kiến trúc Flask, bản đồ chức năng              | Mục 5.3–5.4                | Phú           | —          |
| Chạy demo, chụp Hình 5.2–5.9                        | Mục 5.5                    | Phú           | —          |
| Giới hạn hiện tại, hướng dẫn cài đặt (★ điều chỉnh) | Mục 5.6–5.7                | Nguyên        | Phú        |
| Chuẩn bị phần SQL Defense (16 query)                | Mục 5.8                    | Cả nhóm       | —          |

## Phase 5 – Hoàn thiện và thuyết trình

| **Việc**                                                             | **Sản phẩm**          | **Làm chính** | **Hỗ trợ** |
| -------------------------------------------------------------------- | --------------------- | ------------- | ---------- |
| Tổng hợp, định dạng, kiểm tra mục lục/số hình/số liệu, nộp báo cáo   | File báo cáo cuối     | Nguyên        | Phúc       |
| Đối chiếu số liệu giữa báo cáo, script và ảnh (16 query, T/R, P1–P4) | Biên bản đối chiếu    | Phúc          | Nguyên     |
| Làm slide thuyết trình                                               | File slide            | Phúc          | Nguyên     |
| Chạy demo trực tiếp khi bảo vệ                                       | Kịch bản demo 12 bước | Phú           | —          |