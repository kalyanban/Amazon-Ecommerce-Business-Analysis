create database amazon_ecommerce;
use amazon_ecommerce;

drop table if exists customers;
drop table if exists orders;

create table customers (
	customer_id varchar(250) primary key,
    customer_age int,
    customer_gender text
);

create table orders (
	order_date date,
    order_id varchar(50) primary key,
    delivery_date date,
    customer_id varchar(50),
    location varchar(200),
    zone varchar(50),
    delivery_type varchar(250),
    product_category varchar(250),
    sub_category varchar(250),
    product varchar(250),
    unit_price decimal(10,2),
    shipping_fee decimal(10,2),
    order_quantity int,
    sale_price decimal(10,2),
    status varchar(250),
    reason varchar(350),
    rating int,
    foreign key (customer_id) references customers(customer_id)
);

load data local infile "F:/Data Science/Projects/PowerBI_Projects/customers.csv"
into table customers
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(customer_id, customer_age, customer_gender);

load data local infile "F:/Data Science/Projects/PowerBI_Projects/orders.csv"
into table orders
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(order_date, order_id, delivery_date, customer_id, location, zone, delivery_type, product_category, sub_category, 
product, unit_price, shipping_fee, order_quantity, sale_price, status, reason, rating);


-- Top 5 most valuable customers based on composite score 
with customer_data as (
	select
		customer_id,
        sum(sale_price) as total_revenue,
        count(order_id) as frequency,
        round(avg(sale_price), 2) as average_order_value
    from orders
    group by customer_id
)
select 
	customer_id,
    total_revenue,
    frequency as order_frequency,
    average_order_value,
    round((total_revenue * 0.5 + frequency * 0.3 + average_order_value * 0.2), 2) as composite_score
from customer_data
order by composite_score desc
limit 5;

-- Month over month growth rate of total revenue
with monthly_revenue as (
	select 
		date_format(order_date, '%Y-%m') as months,
		sum(sale_price) as total_revenue
	from orders
	group by months
	order by months
),
monthly_revenue_comparision as (
	select
		months,
		total_revenue as current_month_revenue,
		coalesce(lag(total_revenue) over(order by months), 0) as previous_month_revenue
	from monthly_revenue
)
select
	months,
    current_month_revenue as total_revenue,
    coalesce(round(((current_month_revenue-previous_month_revenue)/previous_month_revenue) * 100, 2), 0) as growth_rate_percentage
from monthly_revenue_comparision
order by growth_rate_percentage desc;

-- Rolling 3 month average revenue for each product category
with product_category_revenue as (
	select distinct
		product_category,
		date_format(order_date, '%Y-%m') as months,
		sum(sale_price) over(partition by product_category, date_format(order_date, '%Y-%m')) as monthly_revenue
	from orders
)
select
	product_category,
    months,
    monthly_revenue,
    round(avg(monthly_revenue) over(order by months rows between 3 preceding and current row), 2) as rolling_average_revenue
from product_category_revenue;

-- set SQL_SAFE_UPDATES = 0;
-- set SQL_SAFE_UPDATES = 1;

-- updated the orders table by applying 15% discount on the `Sale Price` for orders placed by customers who have made at least 10 orders
update orders
set sale_price = sale_price - (sale_price * 0.15)
where customer_id in (
	select customer_id
    from (
		select customer_id
		from orders
		group by customer_id
		having count(order_id) >= 10
	) as customers_order_count
);

-- the average number of days between consecutive orders for customers who have placed at least five orders
with customers_order_dates as (
	select
		customer_id,
        order_id,
        order_date,
        lead(order_date) over(partition by customer_id order by order_date) as next_order_date
    from orders
)
select 
	customer_id,
    avg(datediff(next_order_date, order_date)) as avg_days_between_orders
from customers_order_dates
where next_order_date is not null
group by customer_id
having count(order_id) >= 5;

-- The customers who have generated revenue that is more than 30% higher than the average revenue per customer
select
	customer_id,
    sum(sale_price) as total_revenue
from orders
group by customer_id 
having total_revenue > (select 1.3 * avg(sale_price) from orders)
order by total_revenue desc;

-- the top 3 product categories that have shown the highest increase in sales over the past year compared to the previous year
with past_year_sales as (
	select
		product_category,
        sum(sale_price) as past_year_revenue
    from orders
    where year(order_date) = 2020
    group by product_category
),
previous_year_sales as (
	select
		product_category,
        sum(sale_price) as previous_year_revenue
    from orders
    where year(order_date) = 2019
    group by product_category
),
revenue_difference_data as (
	select
		p1.product_category,
		past_year_revenue as year_2020_revenue,
		previous_year_revenue as year_2019_revenue,
		past_year_revenue - previous_year_revenue as revenue_difference,
		dense_rank() over(order by (past_year_revenue - previous_year_revenue) desc) as revenue_difference_rank
	from past_year_sales p1
	join previous_year_sales p2
	on p1.product_category = p2.product_category
)
select
	product_category,
    year_2020_revenue,
    year_2019_revenue,
    revenue_difference as increase_in_sales
from revenue_difference_data
where revenue_difference_rank <= 3
order by increase_in_sales desc;


















