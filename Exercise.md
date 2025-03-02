# SQL Queries for Fetch Data Analysis

This document contains SQL queries answering three questions about Fetch data - two closed-ended questions and one open-ended question.

## Data Distribution Context

![User Age Distribution](https://i.imgur.com/your-image-url.jpg)

*The chart shows the age distribution of users, with the 21-30 age group being the largest at 26.21% of the user base. Other notable groups include 41-50, 31-40, 51-60, with the 71-80 age group representing only 2.70% of users.*

## Data Imputation Approach

<details>
<summary>Data Imputation Process for Missing User Ages</summary>

Since 99.48% of users in the transactions table are not present in the users table, we needed to impute age data to maintain the distribution shown in the chart above. This imputation was necessary for answering age-related questions accurately.

```sql
WITH cte_new_users AS (
    -- Identifying unique users from transactions_cleaned table that are not in users_cleaned
    -- and capturing the earliest purchase date as created_date
    SELECT DISTINCT t.user_id, MIN(t.purchase_date) AS created_date
    FROM transactions_cleaned t
    LEFT JOIN users_cleaned_copy u ON t.user_id = u.id
    WHERE u.id IS NULL
    GROUP BY t.user_id
),
cte_age_distribution AS (
    -- Calculating the percentage distribution of users across different age groups
    -- based on the existing users_cleaned table and excluding the outliers
    SELECT
        CASE
            WHEN age BETWEEN 11 AND 20 THEN '11-20'
            WHEN age BETWEEN 21 AND 30 THEN '21-30'
            WHEN age BETWEEN 31 AND 40 THEN '31-40'
            WHEN age BETWEEN 41 AND 50 THEN '41-50'
            WHEN age BETWEEN 51 AND 60 THEN '51-60'
            WHEN age BETWEEN 61 AND 70 THEN '61-70'
            ELSE '71-80'
        END AS age_group,
        ROUND(COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM users_cleaned WHERE age IS NOT NULL AND age BETWEEN 11 AND 80), 2) AS percentage_of_total
    FROM users_cleaned
    WHERE age IS NOT NULL AND age BETWEEN 11 AND 80
    GROUP BY age_group
),
cte_distributed_users AS (
    -- Determining the exact number of new users to assign to each age group
    -- Logic
    -- Multiplies the percentage of each age group by the total number of missing users, which gives the exact count of users that should go into each bin.
    -- This ensures that the new users are distributed proportionally, maintaining the same age distribution as the existing users.
    SELECT age_group,
        ROUND(percentage_of_total /
        100.0 * (SELECT COUNT(*) FROM cte_new_users)) AS num_users
    FROM cte_age_distribution
),
ranked_cte_new_users AS (
    -- Generates a unique row number for each missing user
    -- Logic
    -- This guarantees that every age group receives the correct number of users without exceeding or falling short of the expected distribution
    -- Users are placed into age groups by comparing their row number to the cumulative count of users needed for each group
    SELECT m.user_id, m.created_date,
        ROW_NUMBER() OVER () AS row_num
    FROM cte_new_users m
),
cte_assigned_users AS (
    -- Assigning an estimated age to each new user based on row number ranking
    -- Uses the cumulative count of required users per age group to allocate ages
    SELECT r.user_id, r.created_date,
        CASE
            WHEN r.row_num <= (SELECT SUM(num_users) FROM cte_distributed_users WHERE age_group = '11-20') THEN 15
            WHEN r.row_num <= (SELECT SUM(num_users) FROM cte_distributed_users WHERE age_group IN ('11-20', '21-30')) THEN 25
            WHEN r.row_num <= (SELECT SUM(num_users) FROM cte_distributed_users WHERE age_group IN ('11-20', '21-30', '31-40')) THEN 35
            WHEN r.row_num <= (SELECT SUM(num_users) FROM cte_distributed_users WHERE age_group IN ('11-20', '21-30', '31-40', '41-50')) THEN 45
            WHEN r.row_num <= (SELECT SUM(num_users) FROM cte_distributed_users WHERE age_group IN ('11-20', '21-30', '31-40', '41-50', '51-60')) THEN 55
            WHEN r.row_num <= (SELECT SUM(num_users) FROM cte_distributed_users WHERE age_group IN ('11-20', '21-30', '31-40', '41-50', '51-60', '61-70')) THEN 65
            ELSE 75
        END AS estimated_age
    FROM ranked_cte_new_users r
)
-- Inserting the new users into the users table
INSERT INTO users_cleaned (id, age, birth_date, created_date, state, language, gender)
SELECT
    user_id,
    estimated_age,
    current_date - interval '1 year' * a.estimated_age AS birth_date,
    created_date,
    'unknown' AS state,
    'unknown' AS language,
    'unknown' AS gender
FROM cte_assigned_users;
```

This approach ensures that the age distribution of imputed users matches the observed distribution in the existing user data, making our age-based analysis more accurate and representative.
</details>

## Closed-ended Questions

### 1. What are the top 5 brands by receipts scanned among users 21 and over?

> Note: For age-related questions, we used the imputed user data to maintain the age distribution shown in the chart above.

<details>
<summary>Approach</summary>

To find the top 5 brands by receipts scanned among users who are 21 and over, we need to:
1. Join the transactions, users, and products tables
2. Filter for users who are 21 and over
3. Count distinct receipt IDs grouped by brand
4. Order by the count in descending order
5. Limit to 5 results
6. Exclude "Unknown" brands

</details>

```sql
SELECT 
    p.brand,
    COUNT(DISTINCT receipt_id) AS total_receipts
FROM 
    transactions_cleaned t
JOIN 
    users_cleaned u ON t.user_id = u.id
JOIN 
    products_cleaned p ON p.barcode = t.barcode
WHERE 
    u.age >= 21
    AND p.brand <> 'Unknown'
GROUP BY 
    p.brand
ORDER BY 
    COUNT(DISTINCT receipt_id) DESC
LIMIT 5;
```

**Results:**
| brand | total_receipts |
|-------|----------------|
| COCA-COLA | 494 |
| GREAT VALUE | 355 |
| PEPSI | 340 |
| EQUATE | 322 |
| LAY'S | 298 |

**Analysis:** COCA-COLA is the most popular brand among users 21 and over based on receipt scans, followed by GREAT VALUE, PEPSI, EQUATE, and LAY'S.

### 2. What is the percentage of sales in the Health & Wellness category by generation?

> Note: For age-related questions, we used the imputed user data to maintain the age distribution shown in the chart above.

<details>
<summary>Approach</summary>

To calculate the percentage of sales in the Health & Wellness category by generation, we need to:
1. Create a CTE to get the total sales in the Health & Wellness category
2. Join the transactions, products, and users tables
3. Filter for products in the Health & Wellness category
4. Group users into generations based on age ranges
5. Calculate the total sales by generation
6. Calculate the percentage of total sales for each generation

</details>

```sql
WITH cte_total_sales AS (
    SELECT 
        SUM(final_sale) AS total_sales
    FROM 
        transactions_cleaned t
    JOIN 
        products_cleaned p ON p.barcode = t.barcode
    WHERE 
        TRIM(p.category_1) = 'Health & Wellness'
)
SELECT
    CASE 
        WHEN age < 13 THEN 'Gen Alpha'
        WHEN age BETWEEN 13 AND 28 THEN 'Gen Z'
        WHEN age BETWEEN 29 AND 44 THEN 'Millennials'
        WHEN age BETWEEN 45 AND 60 THEN 'Gen X'
        WHEN age BETWEEN 61 AND 80 THEN 'Boomers'
    END AS generation,
    SUM(t.final_sale) AS total_sales,
    ROUND(SUM(t.final_sale)*100.00/(SELECT total_sales FROM cte_total_sales), 2) || '%' AS percentage_of_total_sales
FROM 
    transactions_cleaned t
JOIN 
    products_cleaned p ON t.barcode = p.barcode
JOIN 
    users_cleaned u ON t.user_id = u.id
WHERE 
    TRIM(p.category_1) = 'Health & Wellness'
GROUP BY 
    generation;
```

**Results:**
| generation | total_sales | percentage_of_total_sales |
|------------|-------------|---------------------------|
| Boomers | 1556.56 | 10.00% |
| Gen X | 5859.48 | 37.63% |
| Gen Z | 5122.46 | 32.90% |
| Millennials | 3033.47 | 19.48% |

**Analysis:** Gen X contributes the highest percentage of sales (37.63%) in the Health & Wellness category, followed by Gen Z (32.90%), Millennials (19.48%), and Boomers (10.00%).

## Open-ended Questions

### 1. Which is the leading brand in the Dips & Salsa category?

<details>
<summary>Approach</summary>

To determine the leading brand in the Dips & Salsa category, we need to:
1. Join the products and transactions tables
2. Filter for products in the Dips & Salsa category
3. Group by brand
4. Calculate various metrics for each brand:
   - Total sales value
   - Total quantity sold
   - Total number of transactions
   - Number of unique users
   - Number and percentage of zero-value transactions
   - Transactions per user (purchase frequency)
5. Order by key metrics (total sales, quantity, transactions) to identify the leader

</details>

```sql
SELECT
    p.brand,
    SUM(t.final_sale) AS total_sale,
    SUM(final_quantity) AS total_quantity,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT user_id) AS unique_users,
    SUM(CASE WHEN t.final_sale = 0 THEN 1 ELSE 0 END) AS transactions_with_zero_sale_value,
    ROUND((SUM(CASE WHEN t.final_sale = 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS zero_sale_percentage,
    CAST((COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT user_id), 0)) AS DECIMAL(10,2)) AS transactions_per_user
FROM 
    products_cleaned p
JOIN 
    transactions_cleaned t ON p.barcode = t.barcode
WHERE 
    TRIM(category_2) = 'Dips & Salsa'
GROUP BY 
    p.brand
ORDER BY 
    total_sale DESC, total_quantity DESC, total_transactions DESC;
```

**Results:**
| brand | total_sale | total_quantity | total_transactions | unique_users | transactions_with_zero_sale_value | zero_sale_percentage | transactions_per_user |
|-------|------------|----------------|-------------------|--------------|----------------------------------|---------------------|----------------------|
| TOSTITOS | 83.98 | 38.00 | 36 | 35 | 19 | 52.78 | 1.03 |
| MARKETSIDE | 53.53 | 16.00 | 16 | 16 | 3 | 18.75 | 1.00 |
| Unknown | 53.40 | 22.00 | 21 | 21 | 12 | 57.14 | 1.00 |
| PACE | 37.56 | 24.00 | 24 | 24 | 12 | 50.00 | 1.00 |
| GOOD FOODS | 36.97 | 9.00 | 9 | 9 | 6 | 66.67 | 1.00 |

**Analysis:** TOSTITOS is the leading brand in the Dips & Salsa category, with the highest total sales ($83.98), highest quantity sold (38 units), and most transactions (36). Notably, TOSTITOS is also the only brand with a slight repeat purchase behavior (1.03 transactions per user) while all other brands show exactly one transaction per user, indicating minimal brand loyalty across the category.

### 2. At what percent has Fetch grown year over year?

<details>
<summary>Approach</summary>

**Assumption:** Since revenue data is not available, we'll measure growth based on new user acquisition year over year.

To calculate year-over-year growth, we need to:
1. Extract the year from user creation dates
2. Count the number of users created each year
3. Calculate the percentage growth from the previous year using the LAG window function

</details>

```sql
SELECT
    EXTRACT(YEAR FROM created_date) AS year,
    COUNT(id) AS total_number_of_users,
    ROUND(100.00 * (COUNT(id) - LAG(COUNT(id)) OVER(ORDER BY EXTRACT(YEAR FROM created_date)))
        / LAG(COUNT(id)) OVER(ORDER BY EXTRACT(YEAR FROM created_date)), 2) AS yoy_growth
FROM 
    users_cleaned tu
GROUP BY 
    1
ORDER BY 
    1;
```

**Final Thoughts:**

Without having the actual results of this query in the provided data, we can make some observations about what the results would tell us:

1. The YoY growth metric shows how Fetch's user base is expanding annually as a percentage
2. Positive growth rates indicate successful user acquisition strategies
3. Negative or declining growth rates would signal potential issues in user acquisition
4. Growth patterns could be correlated with marketing campaigns or app feature releases
5. This analysis could be enhanced with additional metrics like monthly active users (MAU) or revenue per user

For a complete assessment of Fetch's growth, we would ideally analyze multiple dimensions beyond just user signups, including:
- Revenue growth
- Transaction volume growth
- User engagement metrics
- Retention rates
- Average spend per user

The user acquisition growth is just one indicator of the company's overall performance and should be considered alongside other business metrics.
