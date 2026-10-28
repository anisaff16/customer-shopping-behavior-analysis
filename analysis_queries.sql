-- ============================================================
-- Customer Shopping Behavior Analysis
-- Dataset: Customer Shopping Dataset - Retail Sales Data (Kaggle)
-- Platform: Google BigQuery
-- Replace `your_project` with your own BigQuery project ID.
-- ============================================================


-- ============================================================
-- 1. DATA QUALITY CHECKS (raw table)
-- ============================================================

-- 1.1 Row count and unique IDs
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT customer_id) AS unique_customer_ids,
  COUNT(DISTINCT invoice_no) AS unique_invoices
FROM `your_project.retail_project.customer_shopping`;

-- 1.2 Null values, age range, date range
SELECT
  COUNTIF(gender IS NULL) AS null_gender,
  COUNTIF(age IS NULL) AS null_age,
  COUNTIF(price IS NULL) AS null_price,
  MIN(age) AS min_age,
  MAX(age) AS max_age,
  MIN(invoice_date) AS first_date,
  MAX(invoice_date) AS last_date
FROM `your_project.retail_project.customer_shopping`;

-- 1.3 Does `price` scale with `quantity`?
-- The documentation calls price a unit price, but the values grow
-- exactly with quantity (e.g. Clothing: 300.08, 600.16, 900.24, ...),
-- so price is treated as the line total.
SELECT
  quantity,
  COUNT(*) AS total_rows,
  ROUND(MIN(price), 2) AS min_price,
  ROUND(MAX(price), 2) AS max_price
FROM `your_project.retail_project.customer_shopping`
WHERE category = 'Clothing'
GROUP BY quantity
ORDER BY quantity;


-- ============================================================
-- 2. CLEANED TABLE
-- ============================================================
-- price is used as the line total (total_amount);
-- unit_price is derived as price / quantity.
CREATE OR REPLACE TABLE `your_project.retail_project.customer_shopping_clean` AS
SELECT
  invoice_no,
  customer_id,
  gender,
  age,
  category,
  quantity,
  price AS total_amount,
  SAFE_DIVIDE(price, quantity) AS unit_price,
  payment_method,
  invoice_date,
  shopping_mall
FROM `your_project.retail_project.customer_shopping`;

-- 2.1 Check the cleaned table
SELECT
  COUNT(*) AS total_rows,
  ROUND(SUM(total_amount), 2) AS total_revenue,
  ROUND(AVG(total_amount), 2) AS avg_spend,
  SUM(quantity) AS total_items
FROM `your_project.retail_project.customer_shopping_clean`;


-- ============================================================
-- 3. DEMOGRAPHICS
-- ============================================================

-- 3.1 Transactions and revenue by gender
SELECT
  gender,
  COUNT(*) AS transactions,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS transaction_pct,
  ROUND(SUM(total_amount), 0) AS revenue,
  ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY gender;

-- 3.2 Transactions and average spend by age group
SELECT
  CASE
    WHEN age < 25 THEN '18-24'
    WHEN age < 35 THEN '25-34'
    WHEN age < 45 THEN '35-44'
    WHEN age < 55 THEN '45-54'
    ELSE '55-69'
  END AS age_group,
  COUNT(*) AS transactions,
  ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY age_group
ORDER BY age_group;

-- 3.3 Average spend by gender, age group, and mall
SELECT 'gender' AS dimension, gender AS segment, ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY gender
UNION ALL
SELECT 'age_group' AS dimension,
  CASE WHEN age < 25 THEN '18-24' WHEN age < 35 THEN '25-34'
       WHEN age < 45 THEN '35-44' WHEN age < 55 THEN '45-54' ELSE '55-69' END AS segment,
  ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY segment
UNION ALL
SELECT 'mall' AS dimension, shopping_mall AS segment, ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY shopping_mall
ORDER BY dimension, segment;


-- ============================================================
-- 4. MALLS
-- ============================================================

-- 4.1 Transactions, revenue, and revenue share by mall
SELECT
  shopping_mall,
  COUNT(*) AS transactions,
  ROUND(SUM(total_amount), 0) AS revenue,
  ROUND(SUM(total_amount) / SUM(SUM(total_amount)) OVER () * 100, 1) AS revenue_pct,
  ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY shopping_mall
ORDER BY revenue DESC;

-- 4.2 Revenue by category and mall (matrix)
SELECT
  shopping_mall,
  category,
  COUNT(*) AS transactions,
  ROUND(SUM(total_amount), 0) AS revenue
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY shopping_mall, category
ORDER BY shopping_mall, revenue DESC;


-- ============================================================
-- 5. CATEGORIES
-- ============================================================

-- 5.1 Transaction share vs revenue share by category
SELECT
  category,
  COUNT(*) AS transactions,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS transaction_pct,
  ROUND(SUM(total_amount), 0) AS revenue,
  ROUND(SUM(total_amount) / SUM(SUM(total_amount)) OVER () * 100, 1) AS revenue_pct,
  ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY category
ORDER BY revenue DESC;

-- 5.2 Average unit price by category
SELECT
  category,
  ROUND(AVG(unit_price), 2) AS avg_unit_price
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY category
ORDER BY avg_unit_price DESC;

-- 5.3 Gender mix by category (share of revenue)
SELECT
  category,
  gender,
  ROUND(SUM(total_amount) / SUM(SUM(total_amount)) OVER (PARTITION BY category) * 100, 1) AS revenue_pct
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY category, gender
ORDER BY category, gender;


-- ============================================================
-- 6. PAYMENT METHODS
-- ============================================================
SELECT
  payment_method,
  COUNT(*) AS transactions,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS transaction_pct,
  ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY payment_method
ORDER BY transactions DESC;


-- ============================================================
-- 7. TIME PATTERNS
-- ============================================================

-- 7.1 Monthly revenue (March 2023 excluded: data ends on Mar 8, 2023)
SELECT
  FORMAT_DATE('%Y-%m', invoice_date) AS month,
  COUNT(*) AS transactions,
  ROUND(SUM(total_amount), 0) AS revenue
FROM `your_project.retail_project.customer_shopping_clean`
WHERE invoice_date < '2023-03-01'
GROUP BY month
ORDER BY month;

-- 7.2 Min and max monthly revenue
SELECT
  ROUND(MIN(revenue), 0) AS min_month,
  ROUND(MAX(revenue), 0) AS max_month
FROM (
  SELECT
    FORMAT_DATE('%Y-%m', invoice_date) AS month,
    SUM(total_amount) AS revenue
  FROM `your_project.retail_project.customer_shopping_clean`
  WHERE invoice_date < '2023-03-01'
  GROUP BY month
);

-- 7.3 Revenue by year (full years only)
SELECT
  FORMAT_DATE('%Y', invoice_date) AS year,
  ROUND(SUM(total_amount), 0) AS revenue
FROM `your_project.retail_project.customer_shopping_clean`
WHERE invoice_date < '2023-01-01'
GROUP BY year
ORDER BY year;

-- 7.4 Transactions by day of week
SELECT
  FORMAT_DATE('%A', invoice_date) AS day_name,
  EXTRACT(DAYOFWEEK FROM invoice_date) AS day_num,
  COUNT(*) AS transactions,
  ROUND(SUM(total_amount), 0) AS revenue
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY day_name, day_num
ORDER BY day_num;


-- ============================================================
-- 8. QUERIES BEHIND THE DASHBOARD INSIGHTS
-- Each query reproduces a headline number used in the dashboard
-- or README. Expected results are in the comments.
-- ============================================================

-- 8.1 Gender share of transactions by age group
-- Expected: Female about 58.8% to 60.3% in every age group
SELECT
  age_group,
  gender,
  COUNT(*) AS transactions,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY age_group) * 100, 1) AS pct
FROM (
  SELECT
    gender,
    CASE
      WHEN age < 25 THEN '18-24'
      WHEN age < 35 THEN '25-34'
      WHEN age < 45 THEN '35-44'
      WHEN age < 55 THEN '45-54'
      ELSE '55-69'
    END AS age_group
  FROM `your_project.retail_project.customer_shopping_clean`
)
GROUP BY age_group, gender
ORDER BY age_group, gender;

-- 8.2 Average age
-- Expected: about 43.43 (min 18, max 69)
SELECT
  ROUND(AVG(age), 2) AS avg_age,
  MIN(age) AS min_age,
  MAX(age) AS max_age
FROM `your_project.retail_project.customer_shopping_clean`;

-- 8.3 Share of revenue from the top 3 categories
-- Expected: about 94.8%
SELECT
  ROUND(
    SUM(IF(category IN ('Clothing', 'Shoes', 'Technology'), total_amount, 0))
    / SUM(total_amount) * 100, 1
  ) AS top3_category_revenue_pct
FROM `your_project.retail_project.customer_shopping_clean`;

-- 8.4 Low-ticket categories: share of transactions vs share of revenue
-- Expected: about 40.2% of transactions, about 4.6% of revenue
SELECT
  ROUND(
    COUNTIF(category IN ('Cosmetics', 'Food & Beverage', 'Toys')) / COUNT(*) * 100, 1
  ) AS transaction_pct,
  ROUND(
    SUM(IF(category IN ('Cosmetics', 'Food & Beverage', 'Toys'), total_amount, 0))
    / SUM(total_amount) * 100, 1
  ) AS revenue_pct
FROM `your_project.retail_project.customer_shopping_clean`;

-- 8.5 Share of revenue from the top 3 malls and the 5 smallest malls
-- Expected: top 3 about 55.2%, 5 smallest about 24.9%
WITH mall AS (
  SELECT shopping_mall, SUM(total_amount) AS revenue
  FROM `your_project.retail_project.customer_shopping_clean`
  GROUP BY shopping_mall
),
ranked AS (
  SELECT
    shopping_mall,
    revenue,
    ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rnk
  FROM mall
)
SELECT
  ROUND(SUM(IF(rnk <= 3, revenue, 0)) / SUM(revenue) * 100, 1) AS top3_malls_pct,
  ROUND(SUM(IF(rnk > 5, revenue, 0)) / SUM(revenue) * 100, 1) AS smallest5_malls_pct
FROM ranked;

-- 8.6 Year-over-year revenue growth, 2022 vs 2021
-- Expected: about 0.18%
WITH yearly AS (
  SELECT
    EXTRACT(YEAR FROM invoice_date) AS yr,
    SUM(total_amount) AS revenue
  FROM `your_project.retail_project.customer_shopping_clean`
  WHERE invoice_date < '2023-01-01'
  GROUP BY yr
)
SELECT
  ROUND(
    (MAX(IF(yr = 2022, revenue, NULL)) / MAX(IF(yr = 2021, revenue, NULL)) - 1) * 100, 2
  ) AS yoy_growth_pct
FROM yearly;
