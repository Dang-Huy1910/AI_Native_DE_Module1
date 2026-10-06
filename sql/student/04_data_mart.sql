-- Buổi 4
-- ============================================================================
-- GRAIN: One row per order_item (Mỗi dòng là một mặt hàng trong một đơn hàng).
-- LÝ DO CHỌN GRAIN:
-- 1. Đây là mức độ chi tiết nguyên tử (atomic grain), phản ánh giao dịch nhỏ nhất của Sales.
-- 2. Cho phép phân tích các chỉ số doanh thu (revenue), số lượng (quantity), chiết khấu (discount)
--    chi tiết tới từng sản phẩm (product) và danh mục hàng hóa (category).
-- 3. Đảm bảo tính linh hoạt: dễ dàng tổng hợp (roll-up) theo ngày, khách hàng, kênh bán
--    hoặc gom nhóm ngược lại theo toàn bộ đơn hàng (order_id).
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS mart;

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- 1. DIM_DATE
-- Business Logic: Chiều thời gian phục vụ phân tích doanh thu theo ngày, tháng,
--                 quý, năm, ngày trong tuần và ngày cuối tuần (weekend).
-- Transformation: 
--   - Nguồn: Không lấy từ OLTP, sinh tự động từ chuỗi ngày (generate_series).
--   - date_key: Dùng số nguyên YYYYMMDD làm Surrogate Key (PK) vì vừa nhẹ (4 bytes),
--     vừa trực quan nhận diện ngày và tối ưu phân vùng (partition) mà không cần decode.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mart.dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_of_month INT NOT NULL,
    month_number INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    quarter_number INT NOT NULL,
    year_number INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. DIM_CUSTOMER
-- Business Logic: Chiều khách hàng phục vụ phân tích sức mua theo khu vực (city),
--                 phân khúc khách hàng (customer_segment), và tỷ lệ rời bỏ (status).
-- Transformation: 
--   - Nguồn: Trích xuất từ bảng core.customers.
--   - customer_key: Chọn Surrogate Key tự tăng (SERIAL) làm PK nhằm tối ưu dung lượng
--     (4 bytes thay vì VARCHAR 12 bytes), tăng tốc JOIN với bảng Fact và tách biệt chu kỳ dữ liệu OLTP.
--   - customer_id: Giữ lại làm Natural/Business Key phục vụ tra cứu đối soát OLTP.
--   - Loại bỏ các trường kỹ thuật vận hành: source_system, ingested_at.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mart.dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id VARCHAR(12) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(200) NOT NULL,
    phone VARCHAR(30),
    city VARCHAR(100),
    customer_segment VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 3. DIM_PRODUCT
-- Business Logic: Chiều sản phẩm phục vụ phân tích doanh số và lợi nhuận theo
--                 từng sản phẩm và danh mục hàng hóa (category).
-- Transformation: 
--   - Nguồn: core.products JOIN với core.categories.
--   - Denormalization: Làm phẳng bằng cách đưa trực tiếp category_name vào chiều sản phẩm.
--   - product_key: Chọn Surrogate Key tự tăng (SERIAL) làm PK để tối ưu hiệu năng JOIN
--     và sẵn sàng hỗ trợ quản lý lịch sử giá/thay đổi thông tin (SCD Type 2).
--   - product_id: Giữ lại làm Natural/Business Key để đối soát.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mart.dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id VARCHAR(12) NOT NULL UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    category_id VARCHAR(10) NOT NULL,
    category_name VARCHAR(120) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    cost_price NUMERIC(12,2) NOT NULL,
    status VARCHAR(20) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 4. DIM_PAYMENT_METHOD
-- Business Logic: Chiều phương thức thanh toán phục vụ phân tích xu hướng sử dụng
--                 tiền mặt, thẻ, chuyển khoản hay ví điện tử.
-- Transformation: 
--   - Nguồn: Trích xuất các giá trị DISTINCT payment_method từ core.payments.
--   - payment_method_key: Chọn Surrogate Key tự tăng (SERIAL) làm PK để chuẩn hóa
--     thành số nguyên 4 bytes, tránh lưu trữ chuỗi text lặp lại trong bảng Fact.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mart.dim_payment_method (
    payment_method_key SERIAL PRIMARY KEY,
    payment_method VARCHAR(30) NOT NULL UNIQUE,
    payment_method_name VARCHAR(50) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 5. DIM_ORDER_STATUS
-- Business Logic: Chiều trạng thái đơn hàng phục vụ lọc và phân tích theo vòng đời
--                 đơn (completed, cancelled, pending, shipped...).
-- Transformation: 
--   - Nguồn: Trích xuất các giá trị DISTINCT status từ core.orders.
--   - order_status_key: Chọn Surrogate Key tự tăng (SERIAL) làm PK giúp tối ưu hóa
--     tốc độ filter và join theo mã số nguyên trong Star Join.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mart.dim_order_status (
    order_status_key SERIAL PRIMARY KEY,
    order_status VARCHAR(20) NOT NULL UNIQUE,
    order_status_name VARCHAR(50) NOT NULL
);

-- ============================================================================
-- 6. FACT_SALES
-- Business Logic: Bảng sự kiện bán hàng lưu trữ các giao dịch chi tiết theo từng mặt hàng.
-- Transformation: 
--   - Nguồn từ core.order_items kết hợp core.orders và core.payments.
--   - Mapping 5 Foreign Keys trỏ tới 5 Dimensions tương ứng để lấy Surrogate Keys.
--   - Degenerate Dimension: order_id giữ lại trực tiếp trong Fact để nhóm theo đơn và đối soát.
--   - Measures: Tính toán quantity, unit_price, discount_amount, gross_revenue, net_revenue.
-- ============================================================================
CREATE TABLE IF NOT EXISTS mart.fact_sales (
    sales_key BIGSERIAL PRIMARY KEY,
    order_item_id VARCHAR(16) NOT NULL UNIQUE,  -- Natural Key từ order_items
    order_id VARCHAR(12) NOT NULL,              -- Degenerate Dimension
    
    -- Foreign Keys tham chiếu tới 5 Dimensions
    date_key INT NOT NULL REFERENCES mart.dim_date(date_key),
    customer_key INT NOT NULL REFERENCES mart.dim_customer(customer_key),
    product_key INT NOT NULL REFERENCES mart.dim_product(product_key),
    payment_method_key INT NOT NULL REFERENCES mart.dim_payment_method(payment_method_key),
    order_status_key INT NOT NULL REFERENCES mart.dim_order_status(order_status_key),
    
    -- Measures (Các thước đo số học tối ưu cho analytics)
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    gross_revenue NUMERIC(12,2) NOT NULL CHECK (gross_revenue >= 0),
    net_revenue NUMERIC(12,2) NOT NULL CHECK (net_revenue >= 0),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes tối ưu hóa hiệu năng truy vấn Star Join
CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON mart.fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer ON mart.fact_sales(customer_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON mart.fact_sales(product_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_order ON mart.fact_sales(order_id);

-- ============================================================================
-- PHẦN 1.3: DATA LOADING (ETL LOAD SCRIPTS) & RECONCILIATION
-- ============================================================================

-- 1. LOAD DIM_DATE (dải ngày sinh tự động từ MIN/MAX order_date)
INSERT INTO mart.dim_date (
    date_key, full_date, day_of_month, month_number, month_name, 
    quarter_number, year_number, day_of_week, day_name, is_weekend
)
SELECT 
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_key,
    d::DATE AS full_date,
    EXTRACT(DAY FROM d)::INT AS day_of_month,
    EXTRACT(MONTH FROM d)::INT AS month_number,
    TRIM(TO_CHAR(d, 'Month')) AS month_name,
    EXTRACT(QUARTER FROM d)::INT AS quarter_number,
    EXTRACT(YEAR FROM d)::INT AS year_number,
    EXTRACT(ISODOW FROM d)::INT AS day_of_week,
    TRIM(TO_CHAR(d, 'Day')) AS day_name,
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend
FROM (
    SELECT generate_series(
        (SELECT MIN(order_date)::date FROM core.orders),
        (SELECT MAX(order_date)::date FROM core.orders),
        '1 day'::interval
    )::date AS d
) s
ON CONFLICT (date_key) DO NOTHING;

-- 2. LOAD DIM_CUSTOMER
INSERT INTO mart.dim_customer (customer_id, full_name, email, phone, city, customer_segment, status)
SELECT customer_id, full_name, email, phone, city, customer_segment, status
FROM core.customers
ON CONFLICT (customer_id) DO NOTHING;

-- 3. LOAD DIM_PRODUCT
INSERT INTO mart.dim_product (product_id, product_name, category_id, category_name, unit_price, cost_price, status)
SELECT 
    p.product_id, 
    p.product_name, 
    p.category_id, 
    c.category_name, 
    p.unit_price, 
    p.cost_price, 
    p.status
FROM core.products p
JOIN core.categories c ON p.category_id = c.category_id
ON CONFLICT (product_id) DO NOTHING;

-- 4. LOAD DIM_PAYMENT_METHOD
INSERT INTO mart.dim_payment_method (payment_method, payment_method_name)
SELECT DISTINCT 
    payment_method, 
    CASE payment_method
        WHEN 'cash' THEN 'Tiền mặt'
        WHEN 'card' THEN 'Thẻ ngân hàng'
        WHEN 'bank_transfer' THEN 'Chuyển khoản'
        WHEN 'e_wallet' THEN 'Ví điện tử'
        ELSE INITCAP(payment_method)
    END
FROM core.payments
UNION
SELECT 'unknown', 'Chưa thanh toán / Không xác định'
ON CONFLICT (payment_method) DO NOTHING;

-- LOAD DIM_ORDER_STATUS
INSERT INTO mart.dim_order_status (order_status, order_status_name)
SELECT DISTINCT 
    status, 
    CASE status
        WHEN 'pending' THEN 'Chờ xử lý'
        WHEN 'confirmed' THEN 'Đã xác nhận'
        WHEN 'shipped' THEN 'Đang giao hàng'
        WHEN 'completed' THEN 'Hoàn thành'
        WHEN 'cancelled' THEN 'Đã hủy'
        ELSE INITCAP(status)
    END
FROM core.orders
ON CONFLICT (order_status) DO NOTHING;

-- 5. LOAD FACT_SALES (JOIN OLTP VÀ TRA CỨU KHÓA DIMENSION)
INSERT INTO mart.fact_sales (
    order_item_id,
    order_id,
    date_key,
    customer_key,
    product_key,
    payment_method_key,
    order_status_key,
    quantity,
    unit_price,
    discount_amount,
    gross_revenue,
    net_revenue
)
SELECT 
    oi.order_item_id,
    oi.order_id,
    d.date_key,
    c.customer_key,
    p.product_key,
    pm.payment_method_key,
    os.order_status_key,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    (oi.quantity * oi.unit_price) AS gross_revenue,
    (oi.quantity * oi.unit_price - oi.discount_amount) AS net_revenue
FROM core.orders o
JOIN core.order_items oi ON o.order_id = oi.order_id
JOIN core.products pr ON oi.product_id = pr.product_id
LEFT JOIN core.payments pay ON o.order_id = pay.order_id
JOIN mart.dim_date d ON o.order_date::date = d.full_date
JOIN mart.dim_customer c ON o.customer_id = c.customer_id
JOIN mart.dim_product p ON oi.product_id = p.product_id
JOIN mart.dim_order_status os ON o.status = os.order_status
JOIN mart.dim_payment_method pm ON COALESCE(pay.payment_method, 'unknown') = pm.payment_method
ON CONFLICT (order_item_id) DO NOTHING;

-- ĐỐI SOÁT DỮ LIỆU OLTP ↔ DATA MART
-- 1. Kiểm tra số lượng bản ghi (Row Count)
SELECT 'mart.dim_date' AS table_name, COUNT(*) AS row_count FROM mart.dim_date
UNION ALL
SELECT 'mart.dim_customer', COUNT(*) FROM mart.dim_customer
UNION ALL
SELECT 'mart.dim_product', COUNT(*) FROM mart.dim_product
UNION ALL
SELECT 'mart.dim_payment_method', COUNT(*) FROM mart.dim_payment_method
UNION ALL
SELECT 'mart.dim_order_status', COUNT(*) FROM mart.dim_order_status
UNION ALL
SELECT 'mart.fact_sales', COUNT(*) FROM mart.fact_sales;

-- 2. Đối soát tổng doanh thu giữa OLTP orders và Mart fact_sales
SELECT 
    (SELECT SUM(order_total) FROM core.orders) AS oltp_orders_total,
    SUM(f.net_revenue) AS mart_fact_net_revenue,
    SUM(f.gross_revenue) AS mart_fact_gross_revenue,
    SUM(f.discount_amount) AS mart_fact_total_discount,
    (SELECT SUM(order_total) FROM core.orders) - SUM(f.net_revenue) AS diff_net_vs_oltp,
    (SELECT SUM(order_total) FROM core.orders) - SUM(f.gross_revenue) AS diff_gross_vs_oltp
FROM mart.fact_sales f;


-- ============================================================================
-- PHẦN 1.4: KPI QUERIES (CHỈ TRUY VẤN TỪ DATA MART, KHÔNG JOIN OLTP)
-- ============================================================================

-- KPI 1: Total revenue by month (Doanh thu thuần và số đơn theo từng tháng)
SELECT 
    d.year_number,
    d.month_number,
    d.month_name,
    SUM(f.net_revenue) AS total_revenue,
    SUM(f.gross_revenue) AS total_gross_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM mart.fact_sales f
JOIN mart.dim_date d ON f.date_key = d.date_key
GROUP BY d.year_number, d.month_number, d.month_name
ORDER BY d.year_number, d.month_number;

-- KPI 2: Revenue by category (Doanh thu và số lượng bán theo danh mục hàng hóa)
SELECT 
    p.category_name,
    SUM(f.net_revenue) AS total_revenue,
    SUM(f.quantity) AS total_quantity_sold,
    ROUND(SUM(f.net_revenue) * 100.0 / SUM(SUM(f.net_revenue)) OVER (), 2) AS revenue_share_pct
FROM mart.fact_sales f
JOIN mart.dim_product p ON f.product_key = p.product_key
GROUP BY p.category_name
ORDER BY total_revenue DESC;

-- KPI 3: Top 10 products theo revenue (Top 10 sản phẩm có doanh thu cao nhất)
SELECT 
    p.product_id,
    p.product_name,
    p.category_name,
    SUM(f.net_revenue) AS total_revenue,
    SUM(f.quantity) AS total_units_sold
FROM mart.fact_sales f
JOIN mart.dim_product p ON f.product_key = p.product_key
GROUP BY p.product_id, p.product_name, p.category_name
ORDER BY total_revenue DESC
LIMIT 10;

-- KPI 4: AOV - Average Order Value (Giá trị đơn hàng trung bình = Total Revenue / Total Orders)
SELECT 
    SUM(f.net_revenue) AS total_revenue,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(SUM(f.net_revenue) / COUNT(DISTINCT f.order_id), 2) AS aov
FROM mart.fact_sales f;

-- KPI 5: Customer count by segment/region (Số lượng khách hàng và doanh thu theo phân khúc & thành phố)
SELECT 
    c.customer_segment,
    c.city AS region,
    COUNT(DISTINCT c.customer_key) AS total_registered_customers,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.net_revenue) AS total_revenue
FROM mart.dim_customer c
LEFT JOIN mart.fact_sales f ON c.customer_key = f.customer_key
GROUP BY c.customer_segment, c.city
ORDER BY total_revenue DESC NULLS LAST;

-- BỔ SUNG KPI 5: Customer & Order distribution by order status (Phân bố theo trạng thái đơn hàng)
SELECT 
    os.order_status,
    os.order_status_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS unique_customers,
    SUM(f.net_revenue) AS total_revenue
FROM mart.fact_sales f
JOIN mart.dim_order_status os ON f.order_status_key = os.order_status_key
GROUP BY os.order_status, os.order_status_name
ORDER BY total_orders DESC;