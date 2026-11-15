-- ============================================================
-- PROJECT: Zomato Order & Customer Analytics
-- Tool: MySQL Workbench | Database: zomato_db
-- Tables: orders, restaurant, users, food, menu
-- Goal: Clean and validate a Zomato-style dataset, then analyse
--       sales, customers, menu pricing and restaurant ratings.
-- Note: INR and USD are analysed separately. Rows in orders are
--       order records, not confirmed unique orders.
-- ============================================================


-- SECTION 1: DATABASE SETUP & INSPECTION
USE zomato_db;
SHOW TABLES;

DESCRIBE food;
DESCRIBE menu;
DESCRIBE orders;
DESCRIBE restaurant;
DESCRIBE users;


-- SECTION 2: DATA CLEANING

-- 2.1 Handling Duplicate Records
-- View sample order records
SELECT * 
FROM orders
LIMIT 10;

-- Check for completely duplicate orders
SELECT
	order_date,
	sales_qty,
	sales_amount,
	currency,
	user_id,
	r_id,
	COUNT(*) AS duplicate_count
FROM orders
GROUP BY
	order_date,
	sales_qty,
	sales_amount,
	currency,
	user_id,
	r_id
HAVING COUNT(*) > 1; 
-- Result: No completely identical records were found
-- in the orders table.

-- 2.2 Handling Missing Values (NULLs)
-- Check for missing values in the orders table
USE zomato_db;
SELECT
    COUNT(*) AS total_rows,
    COUNT(order_date) AS non_null_order_date,
    COUNT(sales_qty) AS non_null_sales_qty,
    COUNT(sales_amount) AS non_null_sales_amount,
    COUNT(currency) AS non_null_currency,
    COUNT(user_id) AS non_null_user_id,
    COUNT(r_id) AS non_null_r_id
FROM orders;
-- Result: No NULL values were found in the orders table



-- 2.3 Standardizing Categorical Values
-- Step 1: Inspect distinct currency values
SELECT DISTINCT currency
FROM orders;
-- Result: The currency column initially contained
-- two representations of INR and one value of USD.

-- Step 2: Investigate currency values and record counts
SELECT
    CONCAT('[', currency, ']') AS currency_value,
    HEX(currency) AS currency_hex,
    LENGTH(currency) AS value_length,
    COUNT(*) AS number_of_records
FROM orders
GROUP BY currency;
-- Result: HEX() revealed that one INR value contained
-- an extra carriage-return character
-- This caused the two INR representations to be treated
-- as separate values.

-- Step 3: Inspect the original and trimmed values
SELECT
    HEX(currency) AS original_hex,
    HEX(TRIM(currency)) AS trimmed_hex,
    LENGTH(currency) AS original_length,
    LENGTH(TRIM(currency)) AS trimmed_length,
    COUNT(*) AS records
FROM orders
GROUP BY
    HEX(currency),
    HEX(TRIM(currency)),
    LENGTH(currency),
    LENGTH(TRIM(currency));
-- Result: TRIM() alone did not remove the carriage return,
-- so an additional cleaning step was required.

-- Step 4: Remove carriage-return characters
UPDATE orders
SET currency = REPLACE(currency, CHAR(13), '')
WHERE HEX(currency) LIKE '%0D%';
-- Result: The unwanted carriage-return character was removed.

-- Step 5: Verify the standardized currency values
SELECT
    currency,
    HEX(currency) AS currency_hex,
    LENGTH(currency) AS value_length,
    COUNT(*) AS number_of_records
FROM orders
GROUP BY currency;
-- Final result: Two distinct currency values remain:
-- INR: 150279 records
-- USD: 2 records

-- 2.4 Data Type Inspection and Data Quality checks
USE zomato_db;
DESCRIBE orders;

-- Inspect  sample order records
SELECT *
FROM orders
LIMIT 10;
-- Result: The initial sample included a record with a negative
-- sales amount of -1.00. A full-table check found two such records.

-- Check for negative sales amounts
USE zomato_db;
SELECT
    MIN(sales_amount) AS minimum_amount,
    MAX(sales_amount) AS maximum_amount,
    COUNT(*) AS total_records,
    SUM(
        CASE
            WHEN sales_amount < 0 THEN 1
            ELSE 0
        END
    ) AS negative_amount_records
FROM orders;
-- Result: Across 150,281 order records, sales_amount ranges
-- from -1.00 to 1,510,944.00. Two records have negative amounts.

-- Inspect the highest sales amounts
SELECT *
FROM orders
ORDER BY sales_amount DESC
LIMIT 10;
-- Result: The 10 largest records are all INR, from 1,228,148.00 to
-- 1,510,944.00, with quantities from 360 to 1,798 items. Amounts
-- match quantities, so these look like very large bulk orders, not
-- entry errors. Retained unchanged and flagged as potential outliers.

-- Inspect records with negative sales amounts
SELECT *
FROM orders
WHERE sales_amount < 0;
-- Result: Two records have negative sales amounts of -1.00.
-- Decision: Kept unchanged. They may be reversals, refunds or
-- data errors, and the data does not show which.

-- Check for zero or negative sales quantities
USE zomato_db;
SELECT
    COUNT(*) AS total_records,
    SUM(
        CASE
            WHEN sales_qty <= 0 THEN 1
            ELSE 0
        END
    ) AS non_positive_quantity_records
FROM orders;
-- Result: No records have a sales quantity of zero or below.

-- SECTION 3: EXPLORATORY DATA ANALYSIS
-- 3.1 Total Orders and Revenue
USE zomato_db;
SELECT
    currency,
    COUNT(*) AS total_orders,
    SUM(sales_qty) AS total_items_sold,
    SUM(sales_amount) AS total_revenue,
    ROUND(AVG(sales_amount), 2) AS average_sales_amount,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM orders
GROUP BY currency
ORDER BY currency;
-- Result: The orders table has 150,279 INR records and 2 USD records.
-- INR: 2,444,225 items sold, total revenue 986,564,266.00,
--      average 6,564.88 per record, from 2017-10-04 to 2020-06-26.
-- USD: 95 items sold, total revenue 750.00, average 375.00 per
--      record, dated 2017-11-20 and 2017-11-22.
-- The 2 USD records are too few for any meaningful USD analysis.

-- 3.2 Monthly Sales Trend
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    currency,
    COUNT(*) AS total_records,
    SUM(sales_qty) AS total_items_sold,
    SUM(sales_amount) AS monthly_sales
FROM orders
GROUP BY
    DATE_FORMAT(order_date, '%Y-%m'),
    currency
ORDER BY
    order_month,
    currency;
    -- Result: INR sales run from 2017-10 to 2020-06 (33 months).
-- The only USD records (2) fall in 2017-11 and total 750.00,
-- which is too little to show a trend.
-- Peak month: 2018-01 (42,521,659.00). Lowest full month:
-- 2019-12 (22,580,255.00).
-- Monthly sales were mostly 27M-42M in 2018, 22M-35M in 2019
-- and 23M-27M in 2020 (Jan-May), so sales trend downward
-- over the period. Order records fall similarly, from about
-- 4,300-5,500 a month in 2018 to about 3,600-4,000 in 2020.
-- 2017-10 and 2020-06 are partial months (data runs from
-- 2017-10-04 to 2020-06-26), so their lower figures are not
-- real dips.
    
-- 3.3 Top 10 Restaurants by Sales
SELECT
    o.r_id AS restaurant_id,
    o.currency,
    SUM(o.sales_amount) AS total_sales,
    SUM(o.sales_qty) AS total_items_sold,
    COUNT(*) AS total_orders
FROM orders o
INNER JOIN restaurant r
    ON o.r_id = r.id
WHERE o.currency = 'INR'
GROUP BY
    o.r_id,
    o.currency
ORDER BY total_sales DESC
LIMIT 10;
-- Result: The top 10 restaurants by INR sales each have exactly 1
-- order record, with sales from 1,228,148.00 to 1,510,944.00.
-- These are the same very large orders found in Section 2.4
-- (e.g. restaurant 377150: 725 items, 1,510,944.00).
-- Interpretation: The ranking reflects single bulk orders, not
-- sustained restaurant performance, so it should not be read as
-- "best-performing restaurants".

-- 3.4 Sales Performance by Currency
SELECT
    currency,
    COUNT(*) AS total_order_records,
    ROUND(AVG(sales_amount), 2) AS average_order_value,
    MIN(sales_amount) AS minimum_order_value,
    MAX(sales_amount) AS maximum_order_value
FROM orders
GROUP BY currency
ORDER BY currency;
-- Result: INR order records average 6,564.88, with sales amounts from
-- -1.00 to 1,510,944.00. The 2 USD records average 375.00
-- (250.00 to 500.00), too few to compare with INR.
-- Note: The INR minimum of -1.00 is one of the two negative
-- records documented in Section 2.4. The maximum is far above the
-- average, so a few very large orders pull the average up and
-- it should be read with caution.

-- 3.5 Food Item and Dietary Classification Analysis
USE zomato_db;
DESCRIBE food;
DESCRIBE menu;

-- Vegetarian vs Non-Vegetarian Analysis
SELECT
    veg_or_non_veg,
    COUNT(*) AS total_food_items
FROM food
GROUP BY veg_or_non_veg
ORDER BY total_food_items DESC;
-- Result: The food table has 372,561 items: 270,775 Veg (about 73%)
-- and 100,784 Non-veg (about 27%). Two items have no valid dietary
-- classification: one is blank and one is NULL.

-- Inspect food items with missing dietary classifications
SELECT *
FROM food
WHERE veg_or_non_veg IS NULL
   OR TRIM(veg_or_non_veg) = '';
-- Result: Two food items have no valid dietary classification.
-- fd413746 has a blank item name and a blank classification.
-- fd1038996 has the item 'Mushroom Corn Biryani,Veg' with a NULL
-- classification, so the 'Veg' label was stored inside the item
-- name instead of in veg_or_non_veg (a data-entry/import issue).

-- Investigate missing food item details
USE zomato_db;
SELECT
    f_id,
    CONCAT('[', item, ']') AS item_display,
    LENGTH(item) AS item_length,
    HEX(item) AS item_hex,
    veg_or_non_veg
FROM food
WHERE f_id IN ('fd413746', 'fd1038996');
-- Result: fd413746 has an empty item name (length 0) and a blank
-- classification. fd1038996 has the item 'Mushroom Corn Biryani,Veg'
-- and a NULL classification: the 'Veg' label was stored inside the
-- item name instead of in veg_or_non_veg.
-- Decision: Both rows were kept unchanged and documented as
-- data-quality issues. They are 2 of 372,561 food items, so they
-- do not materially affect the veg/non-veg counts.

-- 3.6 Customer Demographic Analysis
USE zomato_db;
DESCRIBE users;

-- Analyze customer demographics by age and gender
SELECT
    gender,
	COUNT(*) AS customers_with_age,
    ROUND(AVG(age), 2) AS average_age,
    MIN(age) AS minimum_age,
    MAX(age) AS maximum_age
FROM users
WHERE age IS NOT NULL
GROUP BY gender
ORDER BY customers_with_age DESC;
-- Result: The customer demographic analysis shows that 57,218 male customers 
-- and 42,782 female customers had available age information. The average
-- age was 24.79 years for males and 24.42 years for females.

-- 3.7 RFM Metrics by Customer and Currency.
-- Calculate recency, frequency, and monetary value for each customer
SELECT
    o.currency,
    o.user_id,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF(
        c.latest_order_date,
        MAX(o.order_date)
    ) AS recency_days,
    COUNT(*) AS frequency,
    SUM(o.sales_amount) AS monetary_value
FROM orders o
JOIN (
    SELECT
        currency,
        MAX(order_date) AS latest_order_date
    FROM orders
    GROUP BY currency
) c
    ON c.currency = o.currency
WHERE o.user_id IS NOT NULL
GROUP BY
    o.currency,
    o.user_id,
    c.latest_order_date
ORDER BY
    o.currency,
    monetary_value DESC;    
-- Result: Recency, frequency and monetary value were calculated for
-- each customer within each currency (recency is measured from the
-- latest order date of that currency).
-- Among the top INR spenders, monetary value ranges from about
-- 970,000 to 1,515,000, frequency is only 1 to 4 order records,
-- and recency varies widely (14 to 878 days).
-- Note: These top values are driven by single very large orders
-- (see Section 2.4). For example, user 70591's total of 1,514,634.00
-- includes one 1,510,944.00 record. This query calculates R, F and M
-- values only; no scores or segments are assigned.
    
-- 3.8 Repeat Customer Analysis
-- Identify customers who placed more than one order
SELECT
    COUNT(*) AS customers_with_orders,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
        AS repeat_customers,
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END)
        AS one_time_customers,
    ROUND(
        100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS repeat_customer_percentage
FROM (
    SELECT user_id, COUNT(*) AS order_count
    FROM orders
    WHERE user_id IS NOT NULL
    GROUP BY user_id
) AS customer_orders;
-- Result: 77,929 customers placed orders; 44,472 (57.07%) placed
-- more than one order record and 33,457 placed only one.
-- Note: Frequency counts rows in orders, not confirmed unique orders.

-- 3.9 Menu Price Analysis by Cuisine
-- Verify columns required for cuisine analysis
USE zomato_db;
DESCRIBE menu;
DESCRIBE food;

-- Analyze menu prices by cuisine
SELECT
    m.cuisine,
    COUNT(DISTINCT m.f_id) AS total_food_items,
    ROUND(AVG(m.price), 2) AS average_menu_price,
    ROUND(MIN(m.price), 2) AS minimum_menu_price,
    ROUND(MAX(m.price), 2) AS maximum_menu_price
FROM menu m
WHERE m.cuisine IS NOT NULL
  AND TRIM(m.cuisine) <> ''
  AND m.price IS NOT NULL
GROUP BY m.cuisine
ORDER BY average_menu_price DESC;
-- Result: Cuisine values contain combined labels such as
-- 'Healthy Food,Snacks' and 'Asian,Desserts', rather than
-- consistently representing a single cuisine.
-- Some menu prices are also recorded as 0.00.
-- These data-quality issues should be considered when
-- interpreting cuisine-level average menu prices.

-- 3.10 Restaurant Ratings vs Order Sales
-- Step 1: Inspect restaurant ratings and rating counts
USE zomato_db;
SELECT
    COUNT(*) AS total_restaurants,
    SUM(CASE WHEN rating IS NULL OR TRIM(rating) = ''
        THEN 1 ELSE 0 END) AS missing_ratings,
    SUM(CASE WHEN rating REGEXP '^[0-9]+(\\.[0-9]+)?$'
        THEN 1 ELSE 0 END) AS numeric_ratings,
    SUM(CASE WHEN rating_count IS NULL
                  OR TRIM(rating_count) = ''
        THEN 1 ELSE 0 END) AS missing_rating_counts
FROM restaurant;
-- Result: Of 148,515 restaurants, 61,430 have numeric ratings and 86
-- have NULL or blank ratings. The other 86,999 have a non-numeric
-- label (e.g. '--').

-- Step 2: Calculate statistics for valid restaurant ratings
SELECT
    COUNT(*) AS rated_restaurants,
    ROUND(AVG(CAST(rating AS DECIMAL(4,2))), 2)
        AS average_rating,
    MIN(CAST(rating AS DECIMAL(4,2))) AS minimum_rating,
    MAX(CAST(rating AS DECIMAL(4,2))) AS maximum_rating
FROM restaurant
WHERE rating REGEXP '^[0-9]+(\\.[0-9]+)?$';
-- Result: A total of 61,430 restaurants have numeric ratings.
-- The average rating is 3.89 out of 5, with ratings ranging
-- from 1.00 to 5.00.

-- Step 3: Check order volume distribution by restaurant
SELECT
    r_id AS restaurant_id,
    currency,
    COUNT(*) AS order_records,
    COUNT(DISTINCT user_id) AS distinct_customers,
    SUM(sales_qty) AS total_items_sold,
    SUM(sales_amount) AS total_sales
FROM orders
GROUP BY
    r_id,
    currency
ORDER BY
    order_records DESC
LIMIT 10;
-- Result: Restaurant ID 0 has by far the most order records (1,617,
-- INR, 22,305,741.00). Every other restaurant in the top 10 has
-- only 2 records, so most restaurants have very few orders.

-- Step 4: Validate restaurant IDs between both tables
SELECT
    COUNT(*) AS total_order_records,
    COUNT(DISTINCT o.r_id) AS distinct_order_restaurant_ids,
    SUM(CASE WHEN o.r_id = 0 THEN 1 ELSE 0 END)
        AS orders_with_restaurant_id_zero,
    SUM(CASE WHEN r.id IS NOT NULL THEN 1 ELSE 0 END)
        AS matched_order_records,
    COUNT(DISTINCT r.id) AS matched_restaurants
FROM orders o
LEFT JOIN restaurant r
    ON o.r_id = r.id;
-- Result: Of 150,281 order records, 148,638 match a restaurant and
-- 1,643 do not. Of the unmatched records, 1,617 use restaurant ID 0.

-- Step 5: Identify orders with unmatched restaurant IDs
SELECT
    o.r_id AS unmatched_restaurant_id,
    COUNT(*) AS order_records
FROM orders o
LEFT JOIN restaurant r
    ON o.r_id = r.id
WHERE r.id IS NULL
GROUP BY o.r_id
ORDER BY order_records DESC
LIMIT 10;
-- Result: 1,617 of the unmatched records use restaurant ID 0.
-- All other unmatched IDs have 1 record each, so ID 0 looks like
-- a placeholder for an unknown restaurant.

-- Step 6: Compare restaurant ratings with order volume by currency
SELECT
    o.currency,
    CASE
        WHEN CAST(r.rating AS DECIMAL(4,2)) >= 4.0
            THEN 'High Rating (4.0+)'
        WHEN CAST(r.rating AS DECIMAL(4,2)) >= 3.0
            THEN 'Medium Rating (3.0-3.9)'
        ELSE 'Low Rating (Below 3.0)'
    END AS rating_category,
    COUNT(DISTINCT r.id) AS total_restaurants,
    COUNT(o.r_id) AS total_order_records,
    ROUND(AVG(o.sales_amount), 2) AS average_order_sales,
    ROUND(SUM(o.sales_amount), 2) AS total_sales
FROM restaurant r
INNER JOIN orders o
    ON r.id = o.r_id
WHERE r.rating REGEXP '^[0-9]+(\\.[0-9]+)?$'
GROUP BY
    o.currency,
    rating_category
ORDER BY
    o.currency,
    rating_category;
-- Result: Among INR-denominated matched orders, medium-rated restaurants
-- generated the highest total sales (210,873,332.00), followed by
-- high-rated restaurants (196,945,118.00). Low-rated restaurants had
-- the highest average order sales (7,798.89), while high-rated 
-- restaurants had the lowest (6,288.76). The USD results contain 
-- only two matched order records, so they are insufficient for meaningful
-- comparison. These results describe associations and do not establish causation.
-- Note: Orders with restaurant ID 0 are excluded (no rating).
-- Note: The low-rated group has only about 2,300 records, so a few large orders
-- can move its average.


-- KEY FINDINGS
-- 1. 150,281 order records: 150,279 INR and 2 USD (2017-10 to 2020-06).
-- 2. A hidden carriage return split INR into two values; fixed in 2.3.
-- 3. INR monthly sales trend downward from 2018 to 2020.
-- 4. 57.07% of customers with orders placed more than one order record.
-- 5. Most restaurants have about one order; the top "restaurants" are
--    single very large orders.
-- 6. Medium-rated restaurants had the highest total INR sales;
--    low-rated had the highest average (association only).
--
-- LIMITATIONS
-- Only 2 USD records; 2 negative amounts kept unchanged; 1,643 order
-- records have no matching restaurant (1,617 with ID 0); 86,999
-- restaurants have a non-numeric rating ('--'); cuisine labels are
-- combined and some menu prices are 0.00; ratings vs sales shows
-- association, not causation.
