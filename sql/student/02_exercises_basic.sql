-- Q1 - Q5
SELECT *
FROM core.orders
WHERE order_total > 100;

select * from core.customers c left join core.orders o on c.customer_id = o.customer_id 
where o.order_id is null;


with top10_spenders as (
	select c.customer_id, sum(o.order_total ) as total_spending, count(o.order_id ) as total_order
	from core.customers c inner join core.orders o on c.customer_id = o.customer_id
	where o.status = 'completed'
	group by c.customer_id
	order by total_spending desc
	limit 10
)

SELECT 
    c.customer_id,
    c.full_name,
    c.email,
    t.total_spending
FROM top10_spenders t
INNER JOIN core.customers c ON t.customer_id = c.customer_id
ORDER BY t.total_spending DESC;


SELECT COUNT(DISTINCT customer_id) AS total_customers_with_orders
FROM core.orders;


select *
from core.orders o 
order by o.order_date desc
limit 5


-- Q6 - Q10
select sum(o.order_total), date_trunc('month', o.order_date )::date as order_month 
from core.orders o 
group by order_month 
order by order_month 

select c.customer_id, c.full_name, AVG(o.order_total) as avg_revenue 
from core.customers c 
inner join core.orders o on c.customer_id = o.customer_id 
group by c.customer_id


select count(o.order_id ) as count_orders, o.status 
from core.orders o 
group by o.status 
order by count_orders 

select c.category_name , SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS total_revenue
from core.order_items oi 
inner join core.products p on oi.product_id = p.product_id 
inner join core.categories c on c.category_id  = p.category_id 
group by c.category_id 
having SUM(oi.quantity * oi.unit_price - oi.discount_amount) > 1000
order by total_revenue


-- Q11 - Q15
select c.full_name, c.email, o.*
from core.orders o
left join core.customers c on o.customer_id = c.customer_id 


select oi.*, p.product_name, p.cost_price 
from core.order_items oi 
join core.products p on oi.product_id  = p.product_id 

select p.*, oi.*
from core.payments p 
join core.orders o on p.order_id = o.order_id 
left join core.order_items oi on o.order_id  = oi.order_id 
where oi.order_item_id is null 

select p.*
from core.products p 
left join core.order_items oi on oi.product_id  = p.product_id 
where oi.order_item_id  is null 

select o.order_id, sum(o.order_total), sum(oi.quantity * oi.unit_price - oi.discount_amount ), sum(o.order_total) - sum(oi.quantity * oi.unit_price - oi.discount_amount ) as diff
from core.orders o 
join core.order_items oi on oi.order_id = o.order_id 
group by o.order_id 
order by diff

