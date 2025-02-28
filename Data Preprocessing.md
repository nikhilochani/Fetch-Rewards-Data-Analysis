# **Data Preprocessing**

## **Step 1: Creating Staging Tables**

To ensure a structured approach to data cleaning, we first create staging tables. These tables allow for data transformations, ensuring consistency and integrity before finalizing the cleaned dataset for analysis.

```sql

Create Table temp_users (
    id Varchar PRIMARY KEY, --All unique records
    Created_date Timestamp NOT NULL,
    birth_date Timestamp,
    state Varchar, --Only two characters. Varchar(2) and Varchar take up the same amount of storage.
    language Varchar,
    gender Varchar 
);

Create Table temp_products (
    category_1 Varchar,
    category_2 Varchar,
    category_3 Varchar,
    category_4 Varchar,
    manufacturer Varchar,
    brand Varchar,
    barcode Bigint --Integer out of range. Hence, using Bigint
);

Create Table temp_transactions (
    receipt_id Varchar,
    purchase_date Timestamp,
    scan_date Timestamp,
    store_name Varchar,
    user_id Varchar,
    barcode Bigint,
    final_quantity Varchar,
    final_sale Varchar
);
commit;
```
## **Objective**
The objective of this preprocessing step is to ensure data integrity in the `products` table by identifying and resolving missing values, handling duplicates, and standardizing the dataset for further analysis.

---

## **1. Identifying Data Quality Issues**
### **Assessing Missing Values**
To evaluate the extent of missing data in key fields, we perform an initial analysis:

```sql
SELECT 
    count(*) || '' AS total_rows,
    Sum(Case when category_1 IS NULL or category_1='' then 1 ELSE 0 end) || '' AS category_1,
	Sum(Case when category_2 IS NULL or category_2='' then 1 ELSE 0 end) || '' AS category_2,
	Sum(Case when category_3 IS NULL or category_3='' then 1 ELSE 0 end) || '' AS category_3,
	Sum(Case when category_4 IS NULL or category_4='' then 1 ELSE 0 end) || '' AS category_4,
    Sum(Case when manufacturer IS NULL or manufacturer='' then 1 ELSE 0 end) || '' AS manufacturer,
    Sum(Case when brand IS NULL or brand=''  then 1 ELSE 0 end) || '' AS brand,
    Sum(Case when barcode IS NULL then 1 ELSE 0 end) || '' AS barcode
FROM temp_products
UNION
SELECT 
    round(count(*)*100.0/count(*)) || '%' AS total_rows,
    round(Sum(Case when category_1 IS NULL or category_1='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_1,
	round(Sum(Case when category_2 IS NULL or category_2='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_2,
	round(Sum(Case when category_3 IS NULL or category_3='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_3,
	round(Sum(Case when category_4 IS NULL or category_4='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_4,
    round(Sum(Case when manufacturer IS NULL or manufacturer='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS manufacturer,
    round(Sum(Case when brand IS NULL or brand=''  then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS brand,
    round(Sum(Case when barcode IS NULL then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS barcode
FROM temp_products;
```
| total_rows | category_1 | category_2 | category_3 | category_4 | manufacturer | brand | barcode |
|------------|------------|------------|------------|------------|------------|------------|------------|
| 845552     | 111        | 1424       | 60566      | 778093     | 226474      | 226472    | 4025     |
| 100%       | 0.01%      | 0.17%      | 7.16%      | 92.02%     | 26.78%      | 26.78%    | 0.48%    |


### **Findings & Cleaning Strategy**
- **`barcode` field**: Contains minimal missing values → Rows with null barcodes should be **deleted** as they provide no analytical value.
- **`category_1` field**: While few values are missing, it is the top category in the hierarchy → Missing values will be **updated to 'Unknown'**.
- **`category_2`, `category_3`, `category_4` fields**: Missing values can be **imputed with 'Unknown'** to maintain consistency.
- **`manufacturer` & `brand` fields**: Missing values make up ~26% → Since very few records have all three (`manufacturer`, `brand`, and `barcode`) missing, those records will be **dropped**.

---

## **2. Handling Missing Values**
### **Step 1: Deleting Rows with Null `barcode`**
```sql
DELETE FROM temp_products 
WHERE barcode IS NULL;

COMMIT;
```

### **Step 2: Imputing Missing Values in Other Columns**
```sql
UPDATE temp_products 
SET category_1 = COALESCE(NULLIF(TRIM(category_1), ''), 'Unknown'),
    category_2 = COALESCE(NULLIF(TRIM(category_2), ''), 'Unknown'),
    category_3 = COALESCE(NULLIF(TRIM(category_3), ''), 'Unknown'),
    category_4 = COALESCE(NULLIF(TRIM(category_4), ''), 'Unknown'),
    manufacturer = COALESCE(NULLIF(TRIM(manufacturer), ''), 'Unknown'),
    brand = COALESCE(NULLIF(TRIM(brand), ''), 'Unknown');

COMMIT;
```

---

## **3. Removing Duplicate Records**
To ensure uniqueness, we create a new cleaned table containing only distinct product records.

```sql
Create table products_cleaned (
    category_1 Varchar,
    category_2 Varchar,
    category_3 Varchar,
    category_4 Varchar,
    manufacturer Varchar,
    brand Varchar,
    barcode Bigint
);

Insert into products_cleaned
Select distinct *
from temp_products;

Commit;
```

---

## **Final Outcome**
✅ Missing `barcode` values removed
✅ `"Unknown"` assigned to missing categories, manufacturer, and brand
✅ Duplicate records removed, ensuring data integrity

This cleaned `products` table is now ready for further integration and analysis.
