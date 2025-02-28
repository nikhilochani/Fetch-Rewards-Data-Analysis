# **Data Preprocessing**

## Index
1. [Introduction](#introduction)
1. [Step 1: Creating Staging Tables](#step-1-creating-staging-tables)
3. [Step 2: Handling Missing Values and Deduplication for Each Table](#step-2-handling-missing-values-and-deduplication-for-each-table)
   - [Users Table](#users-table)
   - [Products Table](#products-table)
   - [Transactions Table](#transactions-table)
4. [Step 3: Inserting and Mapping Across Tables](#step-3-inserting-and-mapping-across-tables)
5. [Step 4: Final Cleaned Tables and ER Diagram](#step-4-final-cleaned-tables-and-er-diagram)


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

![temp_tables](https://github.com/nikhilochani/Fetch/blob/main/temp_tables.png?raw=true)

---

## Step 2: Handling Missing Values and Deduplication for Each Table



### Products Table

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

#### Findings and Cleaning Strategy:
- ***Barcode***: Contains 4,025 missing values (0.48%), which will be deleted as they do not provide analytical value.
- ***Category_1***: 111 missing values (0.01%), which will be updated to 'Unknown' since it represents the highest level of categorization.
- ***Category_2, Category_3, Category_4***: Category_4 has the highest missing percentage (92%), followed by Category_3 (7.16%). Missing values will be imputed with 'Unknown' to maintain consistency.
- ***Manufacturer and Brand***: Approximately 26% missing. Since only a small number of records have all three (manufacturer, brand, and barcode) missing, those records will be dropped, and others will be imputed with 'Unknown'.

##### Deleting Rows with Null Barcode
```sql
Delete from temp_products 
where barcode is null;

commit;
```
##### Imputing Missing Values in Other Columns
```sql
Update temp_products 
Set category_1 = Case when category_1 is null or trim(category_1)='' then 'Unknown' Else category_1 end,
	category_2 = Case when category_2 is null or trim(category_2)='' then 'Unknown' Else category_2 end,
	category_3 = Case when category_3 is null or trim(category_3)='' then 'Unknown' Else category_3 end,
	category_4 = Case when category_4 is null or trim(category_4)='' then 'Unknown' Else category_4 end,
	manufacturer = Case when manufacturer is null or trim(manufacturer)='' then 'Unknown' Else manufacturer end,
	brand = Case when brand is null or trim(brand)='' then 'Unknown' Else brand end;

commit;
```
##### Removing Duplicate Records
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
##### Final State of Products Table
- Missing barcode values removed  
- 'Unknown' assigned to missing categories, manufacturer, and brand  
- Duplicate records removed, ensuring data integrity
- New Products_cleaned table created
---
