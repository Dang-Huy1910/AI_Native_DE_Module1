-- CTE1 - CTE5

WITH customer_total_spending AS (
    SELECT 
        c.customer_id, 
        c.full_name, 
        c.email, 
        SUM(o.order_total) AS total_spending 
    FROM core.customers c
    JOIN core.orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'              
    GROUP BY c.customer_id, c.full_name, c.email
)
SELECT *
FROM customer_total_spending
ORDER BY total_spending DESC
LIMIT 10;     


WITH customer_total_spending AS (
    SELECT 
        c.customer_id, 
        c.full_name, 
        c.email, 
        SUM(o.order_total) AS total_spending
    FROM core.customers c
    JOIN core.orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.full_name, c.email
)
SELECT 
    *,
    CASE 
        WHEN total_spending < 500 THEN 'Low'
        WHEN total_spending BETWEEN 500 AND 2000 THEN 'Medium'
        ELSE 'High'
    END AS spending_tier
FROM customer_total_spending;


WITH orders_per_customer AS (
    SELECT 
        customer_id,
        COUNT(order_id) AS order_count,
        SUM(order_total) AS total_spending
    FROM core.orders
    WHERE status = 'completed'
    GROUP BY customer_id
),
customer_stats AS (
    SELECT 
        ROUND(AVG(order_count), 2) AS avg_orders_per_customer,
        MAX(order_count) AS max_orders_per_customer,
        MIN(order_count) AS min_orders_per_customer,
        ROUND(AVG(total_spending), 2) AS avg_spending_per_customer,
        MAX(total_spending) AS max_spending_per_customer
    FROM orders_per_customer
)
SELECT * 
FROM customer_stats;


WITH customer_orders AS (
    SELECT 
        c.customer_id,
        c.full_name,
        COUNT(o.order_id) AS order_count,
        SUM(o.order_total) AS total_spending
    FROM core.customers c
    JOIN core.orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.full_name
)
SELECT 
    customer_id,
    full_name,
    order_count,
    total_spending,
    ROUND(total_spending / NULLIF(order_count, 0), 2) AS aov
FROM customer_orders
ORDER BY aov DESC;		


WITH customer_cohort AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::date AS cohort_month
    FROM core.orders
    WHERE status = 'completed'
    GROUP BY customer_id
),
monthly_orders AS (
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', order_date)::date AS order_month
    FROM core.orders
    WHERE status = 'completed'
)
SELECT 
    c.cohort_month,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(DISTINCT m.customer_id) AS returned_customers,
    ROUND(
        COUNT(DISTINCT m.customer_id) * 100.0 / COUNT(DISTINCT c.customer_id), 
        2
    ) AS retention_rate_pct
FROM customer_cohort c
LEFT JOIN monthly_orders m 
    ON c.customer_id = m.customer_id 
    AND m.order_month = (c.cohort_month + INTERVAL '1 month')::date
GROUP BY c.cohort_month
ORDER BY c.cohort_month;


-- W1 - W5

WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.full_name,
        SUM(o.order_total) AS total_spending
    FROM core.customers c
    JOIN core.orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.full_name
)
SELECT 
    customer_id,
    full_name,
    total_spending,
    ROW_NUMBER() OVER (ORDER BY total_spending DESC) AS customer_rank
FROM customer_spending;


WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.full_name,
        SUM(o.order_total) AS total_spending
    FROM core.customers c
    JOIN core.orders o ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.full_name
),
ranked_customers AS (
    SELECT 
        customer_id,
        full_name,
        total_spending,
        ROW_NUMBER() OVER (ORDER BY total_spending DESC) AS rn,
        RANK() OVER (ORDER BY total_spending DESC) AS rnk,
        DENSE_RANK() OVER (ORDER BY total_spending DESC) AS dense_rnk
    FROM customer_spending
)
SELECT * 
FROM ranked_customers
WHERE dense_rnk <= 3;


SELECT 
    order_id,
    customer_id,
    order_date,
    order_total,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_sequence
FROM core.orders
WHERE status = 'completed'
ORDER BY customer_id, order_date;


SELECT 
    order_id,
    customer_id,
    order_date,
    order_total,
    LAG(order_total) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_total,
    order_total - LAG(order_total) OVER (PARTITION BY customer_id ORDER BY order_date) AS diff_with_prev,
    LEAD(order_total) OVER (PARTITION BY customer_id ORDER BY order_date) AS next_order_total
FROM core.orders
WHERE status = 'completed'
ORDER BY customer_id, order_date;


WITH daily_revenue AS (
    SELECT 
        order_date::date AS order_day,
        SUM(order_total) AS daily_amount
    FROM core.orders
    WHERE status = 'completed'
    GROUP BY order_date::date
)
SELECT 
    order_day,
    daily_amount,
    SUM(daily_amount) OVER (ORDER BY order_day) AS running_total_revenue
FROM daily_revenue
ORDER BY order_day;


-- RFM

SELECT 
    customer_id,
    (CURRENT_DATE - MAX(order_date)::date) AS recency_days,
    COUNT(order_id) AS frequency,
    SUM(order_total) AS monetary
FROM core.orders
WHERE status = 'completed'
GROUP BY customer_id
ORDER BY recency_days ASC;


-- Cohort

WITH customer_cohort AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::date AS cohort_month
    FROM core.orders
    WHERE status = 'completed'
    GROUP BY customer_id
),
customer_activities AS (
    SELECT DISTINCT
        o.customer_id,
        c.cohort_month,
        (EXTRACT(YEAR FROM o.order_date) - EXTRACT(YEAR FROM c.cohort_month)) * 12 + 
        (EXTRACT(MONTH FROM o.order_date) - EXTRACT(MONTH FROM c.cohort_month)) AS month_number
    FROM core.orders o
    JOIN customer_cohort c ON o.customer_id = c.customer_id
    WHERE o.status = 'completed'
),
cohort_size AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS total_customers
    FROM customer_cohort
    GROUP BY cohort_month
),
retention_matrix AS (
    SELECT 
        ca.cohort_month,
        ca.month_number,
        ROUND(COUNT(DISTINCT ca.customer_id) * 100.0 / cs.total_customers, 2) AS retention_rate
    FROM customer_activities ca
    JOIN cohort_size cs ON ca.cohort_month = cs.cohort_month
    GROUP BY ca.cohort_month, cs.total_customers, ca.month_number
)
SELECT 
    cohort_month,
    MAX(CASE WHEN month_number = 0 THEN retention_rate END) AS m0,
    MAX(CASE WHEN month_number = 1 THEN retention_rate END) AS m1,
    MAX(CASE WHEN month_number = 2 THEN retention_rate END) AS m2,
    MAX(CASE WHEN month_number = 3 THEN retention_rate END) AS m3,
    MAX(CASE WHEN month_number = 4 THEN retention_rate END) AS m4,
    MAX(CASE WHEN month_number = 5 THEN retention_rate END) AS m5
FROM retention_matrix
GROUP BY cohort_month
ORDER BY cohort_month;
