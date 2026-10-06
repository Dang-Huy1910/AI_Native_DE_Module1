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
-- 1. DIM_DATE
-- Business Logic: Chiều thời gian phục vụ phân tích doanh thu theo ngày, tháng,
--                 quý, năm, ngày trong tuần và ngày cuối tuần (weekend).
-- Transformation: 
--   - Nguồn: Không lấy từ OLTP, sinh tự động từ chuỗi ngày (generate_series).
--   - date_key: Tính theo định dạng số nguyên YYYYMMDD làm Surrogate Key.
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
--   - customer_key: Sinh Surrogate Key tự tăng (SERIAL) làm PK cho Data Mart.
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
--   - product_key: Sinh Surrogate Key tự tăng (SERIAL) làm PK.
--   - product_id: Giữ lại làm Natural/Business Key để đối soát.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mart.dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id VARCHAR(12) NOT NULL UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    category_id VARCHAR(10) NOT NULL,
    category_name VARCHAR(120) NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL,
    cost_price NUMERIC(14,2) NOT NULL,
    status VARCHAR(20) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 4. DIM_PAYMENT_METHOD
-- Business Logic: Chiều phương thức thanh toán phục vụ phân tích xu hướng sử dụng
--                 tiền mặt, thẻ, chuyển khoản hay ví điện tử.
-- Transformation: 
--   - Nguồn: Trích xuất các giá trị DISTINCT payment_method từ core.payments.
--   - payment_method_key: Sinh Surrogate Key tự tăng (SERIAL) làm PK.
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
--   - order_status_key: Sinh Surrogate Key tự tăng (SERIAL) làm PK.
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
    
    -- Measures (Các thước đo số học)
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
    discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    gross_revenue NUMERIC(14,2) NOT NULL CHECK (gross_revenue >= 0),
    net_revenue NUMERIC(14,2) NOT NULL CHECK (net_revenue >= 0),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes tối ưu hóa hiệu năng truy vấn Star Join
CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON mart.fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer ON mart.fact_sales(customer_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON mart.fact_sales(product_key);
CREATE INDEX IF NOT EXISTS idx_fact_sales_order ON mart.fact_sales(order_id);