CREATE DATABASE STOCKBIT;

UPDATE stockbit.orderitems
SET shipping_limit_date = STR_TO_DATE(shipping_limit_date, '%m/%d/%Y %H:%i')
WHERE shipping_limit_date IS NOT NULL;


-- 1
WITH CustomerYearlyCount AS (
    SELECT 
        EXTRACT(YEAR FROM o.order_purchase_timestamp) AS year,
        COUNT(DISTINCT c.customer_id) AS total_customers
    FROM 
        STOCKBIT.orders o
    JOIN 
        STOCKBIT.customer c ON o.customer_id = c.customer_id
    GROUP BY 
        EXTRACT(YEAR FROM o.order_purchase_timestamp)
),
CustomerGrowth AS (
    SELECT 
        year,
        total_customers,
        LAG(total_customers) OVER (ORDER BY year) AS prev_year_customers
    FROM 
        CustomerYearlyCount
)
SELECT 
    year,
    total_customers,
    (total_customers - COALESCE(prev_year_customers, total_customers)) * 100.0 / 
    COALESCE(prev_year_customers, total_customers) AS growth_percentage
FROM 
    CustomerGrowth;


-- 2   
-- 2 Percobaan 2
WITH OrderCountsPerState AS (
    SELECT 
        c.customer_state AS state,
        COUNT(o.order_id) AS total_orders,
        COUNT(DISTINCT c.customer_id) AS unique_customers
    FROM 
        STOCKBIT.orders o
    JOIN 
        STOCKBIT.customer c ON o.customer_id = c.customer_id
    GROUP BY 
        c.customer_state
),
StateDensity AS (
    SELECT 
        state,
        total_orders,
        unique_customers,
        total_orders * 1.0 / unique_customers AS order_density
    FROM 
        OrderCountsPerState
)
SELECT 
    state,
    order_density
FROM 
    StateDensity
ORDER BY 
    order_density DESC
LIMIT 1;

-- 2 Percobaan 3
SELECT 
    COALESCE(so.seller_state, co.customer_state) AS state,
    COALESCE(so.total_orders_from_sellers, 0) AS total_orders_from_sellers,
    COALESCE(co.total_orders_from_customers, 0) AS total_orders_from_customers,
    COALESCE(so.total_orders_from_sellers, 0) + COALESCE(co.total_orders_from_customers, 0) AS total_order_density
FROM 
    (SELECT 
        s.seller_state AS seller_state,
        COUNT(oi.order_id) AS total_orders_from_sellers
     FROM 
        STOCKBIT.orderitems oi
     JOIN 
        STOCKBIT.seller s ON oi.seller_id = s.seller_id
     GROUP BY 
        s.seller_state
    ) AS so
LEFT JOIN 
    (SELECT 
        c.customer_state AS customer_state,
        COUNT(o.order_id) AS total_orders_from_customers
     FROM 
        STOCKBIT.orders o
     JOIN 
        STOCKBIT.customer c ON o.customer_id = c.customer_id
     GROUP BY 
        c.customer_state
    ) AS co
ON 
    so.seller_state = co.customer_state

UNION

SELECT 
    COALESCE(so.seller_state, co.customer_state) AS state,
    COALESCE(so.total_orders_from_sellers, 0) AS total_orders_from_sellers,
    COALESCE(co.total_orders_from_customers, 0) AS total_orders_from_customers,
    COALESCE(so.total_orders_from_sellers, 0) + COALESCE(co.total_orders_from_customers, 0) AS total_order_density
FROM 
    (SELECT 
        s.seller_state AS seller_state,
        COUNT(oi.order_id) AS total_orders_from_sellers
     FROM 
        STOCKBIT.orderitems oi
     JOIN 
        STOCKBIT.seller s ON oi.seller_id = s.seller_id
     GROUP BY 
        s.seller_state
    ) AS so
RIGHT JOIN 
    (SELECT 
        c.customer_state AS customer_state,
        COUNT(o.order_id) AS total_orders_from_customers
     FROM 
        STOCKBIT.orders o
     JOIN 
        STOCKBIT.customer c ON o.customer_id = c.customer_id
     GROUP BY 
        c.customer_state
    ) AS co
ON 
    so.seller_state = co.customer_state

ORDER BY 
    total_order_density DESC;
   
-- 2 Percobaan 4
WITH order_density_per_state AS (
    SELECT 
        c.customer_state,
        COUNT(o.order_id) AS total_orders,
        COUNT(DISTINCT c.customer_unique_id) AS total_customers,
        COUNT(o.order_id) / COUNT(DISTINCT c.customer_unique_id) AS order_density
    FROM 
        STOCKBIT.orders o
    INNER JOIN 
        STOCKBIT.customer c ON o.customer_id = c.customer_id
    GROUP BY 
        c.customer_state
)

SELECT 
    customer_state,
    total_orders,
    total_customers,
    order_density
FROM 
    order_density_per_state
ORDER BY 
    order_density DESC;


-- 3
-- Second Highest Selling Product
WITH CategorySales AS (
    SELECT 
        pc.product_category_name,
        pc.product_category_name_english,
        SUM(oi.price) AS total_sales
    FROM 
        STOCKBIT.orderitems oi
    JOIN 
        STOCKBIT.product p ON oi.product_id = p.product_id
    JOIN 
        STOCKBIT.productcategory pc ON p.product_category_name = pc.product_category_name
    GROUP BY 
        pc.product_category_name, pc.product_category_name_english
),
RankedCategories AS (
    SELECT 
        product_category_name,
        product_category_name_english,
        total_sales,
        RANK() OVER (ORDER BY total_sales DESC) AS rank
    FROM 
        CategorySales
)
SELECT 
    product_category_name,
    product_category_name_english,
    total_sales
FROM 
    RankedCategories
WHERE 
    rank = 2;
   
-- Second Lowest Selling Product Category
WITH CategorySales AS (
    SELECT 
        pc.product_category_name,
        pc.product_category_name_english,
        SUM(oi.price) AS total_sales
    FROM 
        STOCKBIT.orderitems oi
    JOIN 
        STOCKBIT.product p ON oi.product_id = p.product_id
    JOIN 
        STOCKBIT.productcategory pc ON p.product_category_name = pc.product_category_name
    GROUP BY 
        pc.product_category_name, pc.product_category_name_english
),
RankedCategories AS (
    SELECT 
        product_category_name,
        product_category_name_english,
        total_sales,
        RANK() OVER (ORDER BY total_sales ASC) AS rank
    FROM 
        CategorySales
)
SELECT 
    product_category_name,
    product_category_name_english,
    total_sales
FROM 
    RankedCategories
WHERE 
    rank = 2;

   
-- 4
WITH DeliveryTimes AS (
    SELECT 
        COUNT(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 END) AS late_deliveries,
        COUNT(CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 END) AS on_time_deliveries,
        COUNT(o.order_id) AS total_orders
    FROM 
        STOCKBIT.orders o
)
SELECT 
    late_deliveries,
    on_time_deliveries,
    (on_time_deliveries * 100.0) / total_orders AS percentage_on_time
FROM 
    DeliveryTimes;

   
-- 5
WITH LateDeliveryRatings AS (
    SELECT 
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
            ELSE 'On Time'
        END AS delivery_status,
        AVG(orv.review_score) AS avg_review_score
    FROM 
        STOCKBIT.orders o
    JOIN 
        STOCKBIT.orderreviews orv ON o.order_id = orv.order_id
    GROUP BY 
        delivery_status
)
SELECT 
    delivery_status,
    avg_review_score
FROM 
    LateDeliveryRatings;




