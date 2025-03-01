# Exercise Part 1: Data Exploration
># Are there any data quality issues present?

Understanding data quality issues is critical to ensuring accurate analysis. Below are key findings that could affect results, along with the SQL queries used to identify them.

### 1. Multiple Records for the Same Barcode in the Products Table

Duplicate barcodes appear in the products table, making it unclear which brand, manufacturer, or category combination should be assigned to a given product. This weakens the expected one-to-many relationship between products and transactions, leading to inconsistencies in analysis.

```sql
With duplicate_barcodes as
(
	Select barcode,count(*) as counter
	from temp_products p
	where barcode is not null
	group by 1
	having count(*)>1
)
Select distinct d.barcode,p.brand,p.manufacturer,p.category_1,p.category_2,p.category_3,p.category_4
from duplicate_barcodes d
join temp_products_copy p on d.barcode=p.barcode
```

**Findings:**

- 185 distinct barcodes have more than one record in the products table.
- Some records have identical details, while others have different brands, manufacturers, or product categories despite sharing the same barcode.

| barcode | brand | manufacturer | category_1 | category_2 | category_3 | category_4 | Notes |
|---------|-------|--------------|------------|------------|------------|------------|-------|
| 400510 | MARS WRIGLEY | STARBURST | Snacks | Candy | Confection Candy | NULL | Identical records |
| 701983 | TRADER JOE'S | TRADER JOE'S | Snacks | Chips | Crisps | NULL | Different records, same barcode ↓ |
| 701983 | SUNRIDGE FARMS | SUNRIDGE FARMS | Snacks | Nuts & Seeds | Snack Seeds | NULL | (Same barcode as above) |
| 404310 | PLACEHOLDER MANUFACTURER | BRAND NOT KNOWN | Snacks | Candy | Chocolate Candy | NULL | Different brand & manufacturer |

### 2. Users Missing from Transactions Table

A significant percentage of users in the transactions table do not exist in the users table, raising concerns about missing data or potential data integration issues.

```sql
Select round(count(distinct t.user_id)*100.00/
                (Select count(distinct user_id)
				from temp_transactions_copy t
				left join temp_users u on t.user_id =u.id),2)
from temp_transactions_copy t
left join temp_users u on t.user_id =u.id
where u.id is null
```

**Findings:**

- 99.48% (17,603 users) from transactions are missing in the users table.
- Further investigation is needed to determine if user records are stored elsewhere.

### 3. Inconsistencies in Transaction Data

There are multiple cases of conflicting values for final_quantity and final_sale, along with duplicate transactions and missing barcodes. A careful inspection of the data revealed these inconsistency patterns:

#### Case 1: Zero or Null final_quantity with Duplicate Pricing

Some transactions have multiple records with final_quantity = 'zero' and final_quantity = 1, yet both share the same price. This suggests redundancy in records.


| receipt_id                              | purchase_date         | scan_date                | store_name      | user_id                   | barcode      | final_quantity | final_sale |
|-----------------------------------------|----------------------|-------------------------|----------------|--------------------------|-------------|---------------|------------|
| f26897a3-c07b-4279-b3d8-8b296c14c827   | 2024-08-13 00:00:00  | 2024-08-19 15:11:34.485 | PIGGLY WIGGLY  | 53ce6404e4b0459d949f33e9 | 41780047175 | zero          | 3.49       |
| f26897a3-c07b-4279-b3d8-8b296c14c827   | 2024-08-13 00:00:00  | 2024-08-19 15:11:34.485 | PIGGLY WIGGLY  | 53ce6404e4b0459d949f33e9 | 41780047175 | 1.00          | 3.49       |

#### Case 2: Missing final_sale Values

Some transactions have identical final_quantity values, but one record is missing final_sale, which could lead to miscalculations in revenue analysis.

| receipt_id                              | purchase_date         | scan_date                | store_name   | user_id                   | barcode        | final_quantity |final_sale |
|-----------------------------------------|----------------------|-------------------------|-------------|--------------------------|--------------|---------------|------------|
| 276889aa-11ae-4ba2-ac26-7c54c9d8fc05   | 2024-08-11 00:00:00  | 2024-08-12 18:26:37.584 | PICK N SAVE | 548e5dfae4b096ae8875dfec | 781138710114 | 1.00          |             |
| 276889aa-11ae-4ba2-ac26-7c54c9d8fc05   | 2024-08-11 00:00:00  | 2024-08-12 18:26:37.584 | PICK N SAVE | 548e5dfae4b096ae8875dfec | 781138710114 | 1.00          |             |

#### Case 3: Null Barcodes

Some transactions lack a barcode, making it impossible to link them to a product.

| receipt_id                              | purchase_date         | scan_date                | store_name | user_id                   | barcode | final_quantity | final_sale |
|-----------------------------------------|----------------------|-------------------------|------------|--------------------------|---------|---------------|------------|
| aa489952-e979-4b84-87d2-a2e6cf8a809b   | 2024-07-31 00:00:00  | 2024-08-01 08:13:40.935 | ALDI       | 56242219e4b07364e3e0bef4 |  Null       | zero          | 1.59       | 
| aa489952-e979-4b84-87d2-a2e6cf8a809b   | 2024-07-31 00:00:00  | 2024-08-01 08:13:40.935 | ALDI       | 56242219e4b07364e3e0bef4 |      Null   | 1.00          | 1.59       | 

#### Case 4: Duplicate Transactions

Some transactions appear more than twice under the same receipt_id, raising concerns about duplicate records.
| receipt_id                              | purchase_date         | scan_date                | store_name | user_id                   | barcode      | final_quantity | final_sale |
|-----------------------------------------|----------------------|-------------------------|------------|--------------------------|-------------|---------------|------------|
| e00cf384-76b3-4090-8688-ac9ba8bdff47   | 2024-07-27 00:00:00  | 2024-08-01 08:11:54.528 | WALMART    | 5e5e92696d598c1178c7f816 | 41789001222 | 1.00          | 0.00       |
| e00cf384-76b3-4090-8688-ac9ba8bdff47   | 2024-07-27 00:00:00  | 2024-08-01 08:11:54.528 | WALMART    | 5e5e92696d598c1178c7f816 | 41789001222 | 0.00          | 0.52       |
| e00cf384-76b3-4090-8688-ac9ba8bdff47   | 2024-07-27 00:00:00  | 2024-08-01 08:11:54.528 | WALMART    | 5e5e92696d598c1178c7f816 | 41789001222 | 1.00          | 0.52       |
| e00cf384-76b3-4090-8688-ac9ba8bdff47   | 2024-07-27 00:00:00  | 2024-08-01 08:11:54.528 | WALMART    | 5e5e92696d598c1178c7f816 | 41789001222 | 1.00          | 0.52       |
  
---
&nbsp; 


     
  
># Are there any fields that are challenging to understand?

Some fields have inconsistent values that make them difficult to interpret.

### 1. Final_quantity Values

Several transactions contain decimal values for final_quantity, suggesting they may represent weight-based measurements rather than discrete units. However, this pattern is also observed in non-perishable items, such as packaged snacks and beverages, making it unclear whether final_quantity is consistently defined across different product categories.

```sql
Select t.barcode, t.final_quantity,
		coalesce(Nullif(trim(brand),''),'Unknown') as brand,
		coalesce(Nullif(trim(manufacturer),''),'Unknown') as manufacturer,
		coalesce(Nullif(trim(category_1),''),'Unknown') as category_1,
				coalesce(Nullif(trim(category_2),''),'Unknown') as category_2,
		coalesce(Nullif(trim(category_3),''),'Unknown') as category_3,
		coalesce(Nullif(trim(category_4),''),'Unknown') as category_4
from temp_transactions_copy_new t join temp_products_copy p on t.barcode=p.barcode
where trim(final_quantity) not in ('','zero')
and final_quantity is not null
--and cast(trim(final_quantity) as numeric)>0
and trim(final_quantity) like '%.%'
and cast(trim(final_quantity) as numeric) != floor(cast(trim(final_quantity) as numeric)) 
and t.barcode is not null
```

| barcode      | final_quantity | brand    | manufacturer   | category_1  | category_2              | category_3 | category_4     |
|-------------|---------------|---------|---------------|------------|------------------------|------------|---------------|
| 12000809996 | 2.57          | PEPSI   | PEPSICO       | Beverages  | Carbonated Soft Drinks | Cola       | Regular Cola  |
| 29000076501 | 0.62          | PLANTERS | HORMEL FOODS  | Snacks     | Nuts & Seeds           | Peanuts    | Unknown       |


**Observations:**

- Many grocery store products follow this pattern, suggesting items sold by weight.
- However, brands like Pepsi (2.57) and Planters (0.62) also show this pattern, which contradicts the weight-based assumption.
- Further clarification is needed on how final_quantity is calculated across different product types.
---
&nbsp; 

## Summary & Next Steps

These data issues could impact analytical accuracy and require further investigation:

- The products table has duplicate barcodes linked to different categories and brands, making product classification inconsistent.
- User data is missing from transactions, raising concerns about whether user records are stored elsewhere.
- Transaction inconsistencies (missing barcodes, duplicate entries, incorrect final quantities) suggest potential issues in data ingestion or scanning methods.


