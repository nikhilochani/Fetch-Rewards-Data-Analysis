--This script involves the Products cleaning process along with a detailed thought process my thought process

SELECT 
    count(*) || '' AS total_rows,
    Sum(Case when category_1 IS null or category_1='' then 1 ELSE 0 end) || '' AS category_1,
	Sum(Case when category_2 IS null or category_2='' then 1 ELSE 0 end) || '' AS category_2,
	Sum(Case when category_3 IS null or category_3='' then 1 ELSE 0 end) || '' AS category_3,
	Sum(Case when category_4 IS null or category_4='' then 1 ELSE 0 end) || '' AS category_4,
    Sum(Case when manufacturer IS null or manufacturer='' then 1 ELSE 0 end) || '' AS manufacturer,
    Sum(Case when brand IS null or brand=''  then 1 ELSE 0 end) || '' AS brand,
    Sum(Case when barcode IS null then 1 ELSE 0 end) || '' AS barcode
FROM temp_products
UNION
SELECT 
    round(count(*)*100.0/count(*)) || '%' AS total_rows,
    round(Sum(Case when category_1 IS null or category_1='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_1,
	round(Sum(Case when category_2 IS null or category_2='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_2,
	round(Sum(Case when category_3 IS null or category_3='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_3,
	round(Sum(Case when category_4 IS null or category_4='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS category_4,
    round(Sum(Case when manufacturer IS null or manufacturer='' then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS manufacturer,
    round(Sum(Case when brand IS null or brand=''  then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS brand,
    round(Sum(Case when barcode IS null then 1 ELSE 0 end)*100.0/count(*),2) || '%' AS barcode
FROM temp_products;
-->From this we identify the columns that need to be taken care of based on the percentage of data missing in the second row
--Barcode—>Percentage seems too low—>null barcodes don't bring in any value to the analysis—>Hence, can be Deleted.
--Category_1—>While category_1 has minimal number of rows missing, we still need to Update/impute "unknown" value as it is the top category in the hierarchy
--Category_2,Category_3,Category_4—>The rest of the category columns can either be left as "unknown" or null
--Manufacturer and Brand—>26% of missing data—> we need to further investigate
		-->Since the number of missing values in the barcode column are close to 4K and this is 220K, it is clear that very few of the records will have
		--all three columns (manufacturer, brand, and barcode) missing. We can easily drop them

--1.Deleting rows with null barcode
Delete from temp_products 
where barcode is null;

commit;

--2. Updating the missing values in all the other columns to 'Unknown"

Update temp_products 
Set category_1 = Case when category_1 is null or trim(category_1)='' then 'Unknown' Else category_1 end,
	category_2 = Case when category_2 is null or trim(category_2)='' then 'Unknown' Else category_2 end,
	category_3 = Case when category_3 is null or trim(category_3)='' then 'Unknown' Else category_3 end,
	category_4 = Case when category_4 is null or trim(category_4)='' then 'Unknown' Else category_4 end,
	manufacturer = Case when manufacturer is null or trim(manufacturer)='' then 'Unknown' Else manufacturer end,
	brand = Case when brand is null or trim(brand)='' then 'Unknown' Else brand end;

commit;


--Handling duplictes

--Inserting unique records from temp_products to products_cleaned table to remove duplicated records
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

--There are still multiple records for the same barcode in products cleaned
--To maintain on-to-many relationship between products_cleaned and transactions_cleaned, using the below dedup logic
--Adding all distinct values in a deduped table

Create table products_deduped as
With cte_category_counts as --This cte prepares results which would help prioritize ranking in the next cte and eventually pushing distinct records into the dedup table
(
	Select
		barcode,
		brand,
		manufacturer,
		category_1,
		category_2,
		category_3,
		category_4,
		(case when category_1 ='Unknown' then 1 else 0 end +
		case when category_2 ='Unknown' then 1 else 0 end +
		case when category_3 ='Unknown' then 1 else 0 end +
		case when category_4 ='Unknown' then 1 else 0 end) as unknown_category_count, --count total number of unknowns
		case when trim(brand) not in ('BRAND NOT KNOWN','Unknown') then 1 else 0 end as brand_priority, --assigning 1 for a known brand and 0 for placeholders
		case when trim(manufacturer) not in ('PLACEHOLDER MANUFACTURER','Unknown') then 1 else 0 end as manufacturer_priority --assigning 1 for a known manufacturer and 0 for placeholders
	from products_cleaned pc
),
cte_ranked_barcodes as
(
	Select  barcode,
			brand,
			manufacturer,
			category_1,
			category_2,
			category_3,
			category_4,
			row_number() over(partition by barcode
								order by brand_priority desc,manufacturer_priority desc,unknown_category_count,random()) as row_num
			--If there's only one record for the barcode, then it autmatically gets assigned row_num=1
			--If there are more than one records per barcode, then it prioritizes based on known brand,manufacturer and total number of known categories in that order
			--Random for a tiebraker
	from cte_category_counts						
)
Select  cast(barcode as varchar), --converting the barcode to match string type in transactions table
		brand,
		manufacturer,
		category_1,
		category_2,
		category_3,
		category_4
from cte_ranked_barcodes
where row_num=1;

commit;

--Dropping the old one and renaming the table Renaming the table
drop table products_cleaned;
Alter table products_deduped rename to products_cleaned;
commit;
