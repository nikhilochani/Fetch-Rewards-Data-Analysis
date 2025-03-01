# Key Data Quality Issues

Understanding data quality issues is critical to ensuring accurate analysis. Below are key findings that could affect results, along with the SQL queries used to identify them.

## 1. Multiple Records for the Same Barcode in the Products Table

Duplicate barcodes appear in the products table, making it unclear which brand, manufacturer, or category combination should be assigned to a given product. This weakens the expected one-to-many relationship between products and transactions, leading to inconsistencies in analysis.

```sql
WITH duplicate_barcodes AS (
    SELECT barcode, COUNT(*) AS counter
    FROM temp_products
    WHERE barcode IS NOT NULL
    GROUP BY 1
    HAVING COUNT(*) > 1
)
SELECT DISTINCT d.barcode, p.brand, p.manufacturer, p.category_1, p.category_2, p.category_3, p.category_4
FROM duplicate_barcodes d
JOIN temp_products p ON d.barcode = p.barcode;
```

**Findings:**

- 185 barcodes have more than one record in the products table.
- Some records have identical details, while others have different brands, manufacturers, or product categories despite sharing the same barcode.

| barcode | brand | manufacturer | category_1 | category_2 | category_3 | category_4 | Notes |
|---------|-------|--------------|------------|------------|------------|------------|-------|
| 400510 | MARS WRIGLEY | STARBURST | Snacks | Candy | Confection Candy | NULL | Identical records |
| 701983 | TRADER JOE'S | TRADER JOE'S | Snacks | Chips | Crisps | NULL | Different records, same barcode |
| 701983 | SUNRIDGE FARMS | SUNRIDGE FARMS | Snacks | Nuts & Seeds | Snack Seeds | NULL | |
| 404310 | PLACEHOLDER MANUFACTURER | BRAND NOT KNOWN | Snacks | Candy | Chocolate Candy | NULL | Different brand & manufacturer |

## 2. Users Missing from Transactions Table

A significant percentage of users in the transactions table do not exist in the users table, raising concerns about missing data or potential data integration issues.

```sql
SELECT 
    ROUND(COUNT(DISTINCT t.user_id) * 100.00 / 
          (SELECT COUNT(DISTINCT user_id) 
           FROM temp_transactions t
           LEFT JOIN temp_users u ON t.user_id = u.id), 2) AS missing_users_percentage
FROM temp_transactions t
LEFT JOIN temp_users u ON t.user_id = u.id
WHERE u.id IS NULL;
```

**Findings:**

- 99.48% (17,603 users) from transactions are missing in the users table.
- Further investigation is needed to determine if user records are stored elsewhere.

## 3. Inconsistencies in Transaction Data

There are multiple cases of conflicting values for final_quantity and final_sale, along with duplicate transactions and missing barcodes.

### Case 1: Zero or Null final_quantity with Duplicate Pricing

Some transactions have multiple records with final_quantity = 0 and final_quantity = 1, yet both share the same price. This suggests redundancy in records.

```sql
SELECT *
FROM temp_transactions
WHERE final_quantity IN ('zero', '0', NULL)
AND barcode IS NOT NULL;
```

| receipt_id | purchase_date | scan_date | store_name | user_id | barcode | final_quantity | final_sale |
|------------|---------------|-----------|------------|---------|---------|----------------|------------|
| f26897a3 | 2024-08-13 | 2024-08-19 | PIGGLY WIGGLY | 53ce6404e4b | 41780047175 | zero | 3.49 |
| f26897a3 | 2024-08-13 | 2024-08-19 | PIGGLY WIGGLY | 53ce6404e4b | 41780047175 | 1.00 | 3.49 |

### Case 2: Missing final_sale Values

Some transactions have identical final_quantity values, but one record is missing final_sale, which could lead to miscalculations in revenue analysis.

```sql
SELECT *
FROM temp_transactions
WHERE final_quantity = '1.00'
AND final_sale IS NULL;
```

### Case 3: Null Barcodes

Some transactions lack a barcode, making it impossible to link them to a product.

```sql
SELECT *
FROM temp_transactions
WHERE barcode IS NULL;
```

### Case 4: Duplicate Transactions

Some transactions appear more than twice under the same receipt_id, raising concerns about duplicate records.

```sql
SELECT receipt_id, COUNT(*)
FROM temp_transactions
GROUP BY receipt_id
HAVING COUNT(*) > 2;
```

## Fields That Are Challenging to Understand

Some fields have inconsistent values that make them difficult to interpret.

### 1. Grocery Store Transactions with Non-Standard final_quantity Values

Several transactions contain final_quantity values between 0 and 1, which suggests weight-based pricing. However, the same pattern is found in non-grocery items, making standardization unclear.

```sql
SELECT t.barcode, t.final_quantity,
       COALESCE(NULLIF(TRIM(brand), ''), 'Unknown') AS brand,
       COALESCE(NULLIF(TRIM(manufacturer), ''), 'Unknown') AS manufacturer,
       COALESCE(NULLIF(TRIM(category_1), ''), 'Unknown') AS category_1,
       COALESCE(NULLIF(TRIM(category_2), ''), 'Unknown') AS category_2,
       COALESCE(NULLIF(TRIM(category_3), ''), 'Unknown') AS category_3,
       COALESCE(NULLIF(TRIM(category_4), ''), 'Unknown') AS category_4
FROM temp_transactions t
JOIN temp_products p ON t.barcode = p.barcode
WHERE TRIM(final_quantity) NOT IN ('', 'zero')
AND final_quantity IS NOT NULL
AND TRIM(final_quantity) LIKE '%.%'
AND CAST(TRIM(final_quantity) AS NUMERIC) != FLOOR(CAST(TRIM(final_quantity) AS NUMERIC));
```

| barcode | final_quantity | brand | manufacturer | category_1 | category_2 | category_3 | category_4 |
|---------|----------------|-------|--------------|------------|------------|------------|------------|
| 12000809996 | 2.57 | PEPSI | PEPSICO | Beverages | Carbonated Soft Drinks | Cola | Regular Cola |
| 86570000034 | 0.62 | PLANTERS | KRAFT HEINZ | Snacks | Nuts & Seeds | Trail Mix | NULL |

**Observations:**

- Many grocery store products follow this pattern, suggesting items sold by weight.
- However, brands like Pepsi (2.57) and Planters (0.62) also show this pattern, which contradicts the weight-based assumption.
- Further clarification is needed on how final_quantity is calculated across different product types.

## Summary & Next Steps

These data issues could impact analytical accuracy and require further investigation:

- The products table has duplicate barcodes linked to different categories and brands, making product classification inconsistent.
- User data is missing from transactions, raising concerns about whether user records are stored elsewhere.
- Transaction inconsistencies (missing barcodes, duplicate entries, incorrect final quantities) suggest potential issues in data ingestion or scanning methods.

Would it be possible to get access to documentation on how user records, transactions, and barcodes are processed? Additionally, clarification on how final_quantity is determined across product types would help refine the analysis.
