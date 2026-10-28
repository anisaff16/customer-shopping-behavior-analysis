# Customer Shopping Behavior Analysis

An end-to-end analysis of 99,457 shopping transactions from 10 malls in Istanbul, using **BigQuery (SQL)** for data exploration and **Power BI** for the dashboard.

> **Note:** The dataset may be synthetic (see [Limitations](#limitations)), so this project is best read as a practice analysis, not a report on real business performance.

---

## Dashboard Preview

<!-- Add your screenshots here, for example: -->
<!-- ![Overview](images/overview.png) -->
<!-- ![Demographics](images/demographics.png) -->
<!-- ![Behavior](images/behavior.png) -->

The dashboard has three pages:

| Page | What it shows |
|---|---|
| **Overview** | Revenue, transactions, monthly trend, revenue by category and mall, key insights and recommendations |
| **Demographics** | Transactions and spend by gender and age group |
| **Behavior** | Payment methods, revenue by category and mall, transactions by day of week, gender mix by category |

---

## Project Goal

Understand who shops, where, and how, and use those patterns to suggest ideas for promotions and loyalty programs. The analysis follows three parts:

1. **Demographics:** total transactions and distribution by gender, age, and mall location.
2. **Shopping behavior:** payment methods, category preferences, day-of-week and monthly patterns.
3. **Business recommendations:** ideas based on the insights.

---

## Dataset

- **Source:** [Customer Shopping Dataset - Retail Sales Data (Kaggle)](https://www.kaggle.com/datasets/mehmettahiraslan/customer-shopping-dataset)
- **Size:** 99,457 rows, 10 columns
- **Period:** Jan 1, 2021 to Mar 8, 2023
- **Currency:** Turkish Lira (TL)

| Column | Description |
|---|---|
| `invoice_no` | Invoice number |
| `customer_id` | Customer ID (created per transaction) |
| `gender` | Customer gender |
| `age` | Customer age (18 to 69) |
| `category` | Product category |
| `quantity` | Number of items |
| `price` | Price (see the data quality note below) |
| `payment_method` | Cash, credit card, or debit card |
| `invoice_date` | Transaction date |
| `shopping_mall` | Mall name |

---

## Tools

- **Google BigQuery:** data upload, cleaning, and SQL analysis
- **Power BI Desktop:** data modeling (DAX measures) and dashboard design

---

## Process

1. **Loaded** the CSV into BigQuery.
2. **Checked data quality:** null values, row counts, age range, and date range.
3. **Cleaned the data** by creating a new table (`customer_shopping_clean`) with the correct date type and a `total_amount` column.
4. **Explored the data with SQL** (category, mall, gender, age, payment method, month, and day of week).
5. **Built the dashboard** in Power BI, with DAX measures and three pages.

### Data quality finding: the `price` column

The dataset documentation describes `price` as a unit price. But when I checked the values, they scale exactly with quantity. For Clothing, price is 300.08 for 1 item, 600.16 for 2, 900.24 for 3, and so on. So `price` already includes quantity, and multiplying by `quantity` would count it twice (it inflated revenue to 251.5M instead of 68.55M).

I treated `price` as the line total. Revenue is `SUM(price)`, and the unit price is `price / quantity`.

```sql
-- Check: does price scale with quantity?
SELECT
  quantity,
  COUNT(*) AS total_rows,
  ROUND(MIN(price), 2) AS min_price,
  ROUND(MAX(price), 2) AS max_price
FROM `your_project.retail_project.customer_shopping`
WHERE category = 'Clothing'
GROUP BY quantity
ORDER BY quantity;
```

### Cleaned table

```sql
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
```

---

## Key SQL Queries

**Revenue and transaction share by category**

```sql
SELECT
  category,
  COUNT(*) AS transactions,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS transaction_pct,
  ROUND(SUM(total_amount), 0) AS revenue,
  ROUND(SUM(total_amount) / SUM(SUM(total_amount)) OVER () * 100, 1) AS revenue_pct
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY category
ORDER BY revenue DESC;
```

**Revenue and average spend by mall**

```sql
SELECT
  shopping_mall,
  COUNT(*) AS transactions,
  ROUND(SUM(total_amount), 0) AS revenue,
  ROUND(AVG(total_amount), 0) AS avg_spend
FROM `your_project.retail_project.customer_shopping_clean`
GROUP BY shopping_mall
ORDER BY revenue DESC;
```

**Monthly revenue (excluding the partial month)**

```sql
SELECT
  FORMAT_DATE('%Y-%m', invoice_date) AS month,
  COUNT(*) AS transactions,
  ROUND(SUM(total_amount), 0) AS revenue
FROM `your_project.retail_project.customer_shopping_clean`
WHERE invoice_date < '2023-03-01'
GROUP BY month
ORDER BY month;
```

**Average spend by gender and age group**

```sql
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
ORDER BY dimension, segment;
```

---

## Key Insights

- **Revenue is concentrated in three categories.** Clothing, Shoes, and Technology contribute 95% of revenue (45.3%, 26.5%, and 23.0%).
- **High-value categories have few transactions.** Technology is 5% of transactions but 23% of revenue. Cosmetics, Food & Beverage, and Toys together are 40% of transactions but under 5% of revenue.
- **Three malls bring in 55% of revenue.** Mall of Istanbul, Kanyon, and Metrocity. The five smallest malls make up about 5% each (about 25% combined).
- **Spend per transaction is similar everywhere.** Average spend is about 690 TL, and it varies only slightly by mall (674 to 705), gender (688 vs 691), and age group (679 to 700). So the gap between malls comes from the number of transactions, not from how much people spend.
- **Revenue is flat.** Monthly revenue stays between 2.3M and 2.8M TL, and 2022 grew only 0.2% from 2021 (nominal).
- **Women make up about 60% of transactions** (59.8%), and this share stays close to 60% across age groups and categories.
- **Cash is the most used payment method** (44.7%), followed by credit card (35.1%) and debit card (20.2%).
- **Transactions are spread evenly across the week** (14,120 to 14,383 per weekday).

---

## Recommendations

These are ideas for consideration, not proven fixes.

1. **Focus on Shoes and Technology**, since they earn the most per transaction.
2. **Investigate why the five smallest malls have fewer transactions.** Spend per transaction is already similar to the larger malls, so the gap is volume. Visitor data would show whether the issue is footfall or conversion.
3. **Collect customer-level data**, for example through a loyalty program, so repeat purchases can be analyzed in the future.

---

## Limitations

- **No persistent customer ID.** `customer_id` is created per transaction, so repeat customers, retention, and loyalty could not be analyzed. For the same reason, I used "transactions" instead of "customers" in the dashboard.
- **`price` is a line total, not a unit price,** despite what the documentation says (see the data quality finding above).
- **The data may be synthetic.** The source does not say whether the data is real, and several patterns suggest it may not be: a Clothing item costs exactly 300.08 in every transaction over more than two years, quantity and age are evenly distributed, and results are almost identical across segments. I treated the results as a practice analysis.
- **Missing fields.** There is no cost, profit, discount, or visitor data, so profitability and promotion effectiveness could not be measured.
- **Partial period.** The data ends on Mar 8, 2023, so March 2023 is excluded from the monthly trend.
- **Age groups are uneven.** The 55-69 group covers 15 years, wider than the other groups (7 to 10 years), so its totals are not directly comparable.

---

## Repository Structure

```
├── README.md
├── Customer_Shopping_Behavior_Analysis.pbix
├── Customer_Shopping_Behavior_Analysis.pdf
├── sql/
│   └── analysis_queries.sql
└── images/
    ├── overview.png
    ├── demographics.png
    └── behavior.png
```

---

## About

**Author:** Anisah Fatin Farahdillah
**LinkedIn:** https://www.linkedin.com/in/anisahfatinfarahdillah/
