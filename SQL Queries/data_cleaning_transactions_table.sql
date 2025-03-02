--This script involves the Transactions table cleaning process along with a detailed thought process my thought process

--Multiple incorrect/duplicate data entries for a single receipt item
--Barcodes missing in the products table
--Taking care of deduplication first and then handling null barcodes—>allows smoother imputation for "Store_name_Unknown_number"

Select 
    count(*) as total_rows,
    Sum(case when receipt_id IS null or receipt_id='' then 1 else 0 end) || '' as receipt_id,
	Sum(case when purchase_date IS null then 1 else 0 end) || '' as purchase_date,
	Sum(case when scan_date IS null then 1 else 0 end) || '' as scan_date,
	Sum(case when store_name IS null or store_name='' then 1 else 0 end) || '' as store_name,
    Sum(case when user_id IS null or user_id='' then 1 else 0 end) || '' as user_id,
    Sum(case when barcode IS null then 1 else 0 end) || '' as barcode,
    Sum(case when final_quantity IS null or final_quantity=' '  then 1 else 0 end) || '' as final_quantity,
    Sum(case when final_sale IS null or final_sale=' '  then 1 else 0 end) || '' as final_sale
from temp_transactions_copy ttc 
UNION ALL
Select 
    count(*)*100.00/count(*) as total_rows,
    round(Sum(case when receipt_id IS null or receipt_id='' then 1 else 0 end)*100.00/count(*),2) || '%' as receipt_id,
	round(Sum(case when purchase_date IS null then 1 else 0 end)*100.00/count(*),2) || '%' as purchase_date,
	round(Sum(case when scan_date IS null then 1 else 0 end)*100.00/count(*),2) || '%' as scan_date,
	round(Sum(case when store_name IS null or store_name='' then 1 else 0 end)*100.00/count(*),2) || '%' as store_name,
    round(Sum(case when user_id IS null or user_id='' then 1 else 0 end)*100.00/count(*),2) || '%' as user_id,
    round(Sum(case when barcode IS null then 1 else 0 end)*100.00/count(*),2) || '%' as barcode,
    round(Sum(case when final_quantity IS null or final_quantity=' '  then 1 else 0 end)*100.00/count(*),2) || '%' as final_quantity,
    round(Sum(case when final_sale IS null or final_sale=' '  then 1 else 0 end)*100.00/count(*),2) || '%' as final_sale
from temp_transactions_copy ttc;


--Couldn't insert as numeric datatype for final_quantity
Select distinct final_quantity
from temp_transactions
where final_quantity !~ '^[+-]?[0-9]+(\.[0-9]+)?$';

--Need to update this to 0.00 and cast final_quantity column to Numeric datatype
--Will consider dropping after performing other quality checks

--Adding numeric columns
Alter table temp_transactions Add column final_quantity_numeric numeric,
							  Add column final_sale_numeric numeric;
commit;

--Populating numeric values for final_quantity and final_sale in the new columns
Update temp_transactions 
SET final_quantity_numeric=case 
					when lower(trim(final_quantity))='zero' then 0.0
					else cast(trim(final_quantity) as numeric)
				end,
	final_sale_numeric=case 
					when final_sale is null or trim(final_sale)='' then 0.0
					else cast(trim(final_sale) as numeric) 
				end;
commit;

--Adding string barcode column
Alter table temp_transactions add column barcode_string varchar;
commit;

--Updating null barcodes with final_quantity_numeric >0 with a barcode that follows the pattern "Store_name" + "_unknown" "final_quantity_numeric"
Update temp_transactions
Set barcode_string =
	case when barcode is not null then cast(barcode as varchar)
		 when barcode is null and final_quantity_numeric > 0 then store_name || '_unknown_' || final_quantity_numeric
	end
commit;

--Creating new table to export values from the staging table
Create Table transactions_cleaned (
    receipt_id varchar,
    purchase_date timestamp,
    scan_date timestamp,
    store_name varchar,
    user_id varchar,
    barcode varchar,
    final_quantity numeric,
    final_sale numeric
);
commit;


--Pushing the duplicate data records without null barcodes into transactions_cleaned table with max values for final_quantity_numeric and final_sale_numeric
With cte_duplicate_rows as --cte identifies records with duplicate values based on grouping by all columns except final_quantity_numeric and final_sale_numeric
(
	Select receipt_id,user_id,purchase_date,scan_date,barcode_string,store_name,count(*)
	from temp_transactions
	--where barcode is not null
	group by receipt_id,user_id,purchase_date,scan_date,barcode_string,store_name
	having count(*)>1
)
Insert into transactions_cleaned(receipt_id,user_id,purchase_date,scan_date,barcode,store_name,final_quantity,final_sale)
Select
	t.receipt_id,
	t.user_id,
	t.purchase_date,
	t.scan_date,
	t.barcode_string,
	t.store_name,
	max(t.final_quantity_numeric),
	max(t.final_sale_numeric)
from cte_duplicate_rows c
join temp_transactions t on t.receipt_id=c.receipt_id and t.barcode_string=c.barcode_string
group by receipt_id,user_id,purchase_date,scan_date,barcode_string,store_name,final_quantity_numeric;

commit;


--Only records left in temp_transactions that are not pushed to transactions_cleaned are the ones with a null barcode

--This query gives all the rows from the temp_transactions table that are not in the transactions_cleaned table
Select *
from temp_transactions t1
left join transactions_cleaned t2 on t1.receipt_id =t2.receipt_id
and t1.user_id=t2.user_id and t1.barcode_string=t2.barcode
where t2.receipt_id is null
order by t1.receipt_id


--Inserting the final eligible records from the remaining rows with null barcodes
Insert into transactions_cleaned(receipt_id,user_id,purchase_date,scan_date,store_name,barcode,final_quantity,final_sale)
Select 
	t1.receipt_id,t1.user_id,t1.purchase_date,t1.scan_date,t1.store_name,
	coalesce(cast(t1.barcode as varchar),max(t1.barcode_string)) as barcode, --Updates the only active barcode created
	max(final_quantity_numeric) as final_quantity, --updates the max for final_quantity (avoiding zeros)
	max(final_sale_numeric) as final_sale --Updates the max for final_sale
from temp_transactions t1
left join transactions_cleaned t2 on t1.receipt_id =t2.receipt_id
and t1.user_id=t2.user_id and t1.barcode_string=t2.barcode
where t2.receipt_id is null
group by t1.receipt_id,t1.user_id,t1.purchase_date,t1.scan_date,t1.store_name,t1.barcode
having max(final_quantity_numeric)>0 -- Avoiding records with final_quantity =0

commit;

--Final transactions_cleaned table has 24796 records
Select count(*)
from transactions_cleaned;






















--Refer to these when cleaning the table

-- case 1: when final_quantity is zero/0/null and 1 for each row and final_sale is the same price—>considering one column with the max(final_quantity)
/*receipt_id	purchase_date	scan_date	store_name	user_id	barcode	final_quantity	final_sale	final_quantity
f26897a3-c07b-4279-b3d8-8b296c14c827	2024-08-13 00:00:00.000	2024-08-19 15:11:34.485	PIGGLY WIGGLY	53ce6404e4b0459d949f33e9	41780047175	zero	3.49	zero
f26897a3-c07b-4279-b3d8-8b296c14c827	2024-08-13 00:00:00.000	2024-08-19 15:11:34.485	PIGGLY WIGGLY	53ce6404e4b0459d949f33e9	41780047175	1.00	3.49	1.00*/

-- case 2: when final_quantity is the same in both rows and final_sale has a value in one row and not in the other then considering one row with the final_quantity and max(final_sale_
/*receipt_id	purchase_date	scan_date	store_name	user_id	barcode	final_quantity	final_sale	final_quantity
276889aa-11ae-4ba2-ac26-7c54c9d8fc05	2024-08-11 00:00:00.000	2024-08-12 18:26:37.584	PICK N SAVE	548e5dfae4b096ae8875dfec	781138710114	1.00	1.99
276889aa-11ae-4ba2-ac26-7c54c9d8fc05	2024-08-11 00:00:00.000	2024-08-12 18:26:37.584	PICK N SAVE	548e5dfae4b096ae8875dfec	781138710114	1.00	 */

-- case 3: null barcode
/*receipt_id	purchase_date	scan_date	store_name	user_id	barcode	final_quantity	final_sale	final_quantity

 aa489952-e979-4b84-87d2-a2e6cf8a809b	2024-07-31 00:00:00.000	2024-08-01 08:13:40.935	ALDI	56242219e4b07364e3e0bef4	nullBarcode	zero	1.59
aa489952-e979-4b84-87d2-a2e6cf8a809b	2024-07-31 00:00:00.000	2024-08-01 08:13:40.935	ALDI	56242219e4b07364e3e0bef4	nullBarcode	1.00	1.59*/

-- case 4:More than 2 entires for one record—>Data quality issue				
/*receipt_id	purchase_date	scan_date	store_name	user_id	barcode	final_quantity	final_sale
e00cf384-76b3-4090-8688-ac9ba8bdff47	2024-07-27 00:00:00.000	2024-08-01 08:11:54.528	WALMART	5e5e92696d598c1178c7f816	41789001222	1.00	0
e00cf384-76b3-4090-8688-ac9ba8bdff47	2024-07-27 00:00:00.000	2024-08-01 08:11:54.528	WALMART	5e5e92696d598c1178c7f816	41789001222	0	0.52
e00cf384-76b3-4090-8688-ac9ba8bdff47	2024-07-27 00:00:00.000	2024-08-01 08:11:54.528	WALMART	5e5e92696d598c1178c7f816	41789001222	1.00	0.52
e00cf384-76b3-4090-8688-ac9ba8bdff47	2024-07-27 00:00:00.000	2024-08-01 08:11:54.528	WALMART	5e5e92696d598c1178c7f816	41789001222	1.00	0.52
*/
-- case 5:				
--How do I merge columns with null barcodes?
/*receipt_id	purchase_date	scan_date	store_name	user_id	barcode	final_quantity	final_sale	final_quantity
9975a373-ad36-4d14-94d1-27aff00ca08b	2024-07-29 00:00:00.000	2024-07-29 19:11:59.475	WEEMERS DIScount GROCERIES	57af9582e4b06f40aeef6f63		zero	5.65
9975a373-ad36-4d14-94d1-27aff00ca08b	2024-07-29 00:00:00.000	2024-07-29 19:11:59.475	WEEMERS DIScount GROCERIES	57af9582e4b06f40aeef6f63		1.00	5.65*/

