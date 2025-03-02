---Exercise Part 2

-- Closed-ended questions:

--Adding records into the users table from transactions: For user_ids not in the users table

with cte_new_users as (
    -- Identifying unique users from transactions_cleaned table that are not in users_cleaned 
    -- and capturing the earliest purchase date as created_date
    select distinct t.user_id, min(t.purchase_date) as created_date
    from transactions_cleaned t
    left join users_cleaned_copy u on t.user_id = u.id
    where u.id is null
    group by t.user_id
),
cte_age_distribution as (
	-- Calculating the percentage distribution of users across different age groups 
    -- based on the existing users_cleaned table and excluding the outliers
    select 
        case 
            when age between 11 and 20 then '11-20'
            when age between 21 and 30 then '21-30'
            when age between 31 and 40 then '31-40'
            when age between 41 and 50 then '41-50'
            when age between 51 and 60 then '51-60'
            when age between 61 and 70 then '61-70'
            else '71-80'
        end as age_group,
        round(count(*) * 100.0 / 
        			(select count(*) from users_cleaned where age is not null and age between 11 and 80), 2) as percentage_of_total
    from users_cleaned
    where age is not null and age between 11 and 80
    group by age_group
),
cte_distributed_users as (
	 -- Determining the exact number of new users to assign to each age group 
-- Logic
    --  Multiplies the percentage of each age group by the total number of missing users, which gives the exact count of users that should go into each bin.  
    --  This ensures that the new users are distributed proportionally, maintaining the same age distribution as the existing users.  
    select age_group, 
           round(percentage_of_total / 
           				100.0 * (select count(*) from cte_new_users)) as num_users
    from cte_age_distribution
),
ranked_cte_new_users as (
		-- Generates a unique row number for each missing user 
-- Logic
	-- This guarantees that every age group receives the correct number of users without exceeding or falling short of the expected distribution
    -- Users are placed into age groups by comparing their row number to the cumulative count of users needed for each group
    select m.user_id, m.created_date, 
           row_number() over () as row_num
    from cte_new_users m
),
cte_assigned_users as (
    -- Assigning ages an estimated age to each new user based on row number ranking
    -- Uses the cumulative count of required users per age group to allocate ages
    select r.user_id, r.created_date,
        case 
            when r.row_num <= (select sum(num_users) from cte_distributed_users where age_group = '11-20') then 15
            when r.row_num <= (select sum(num_users) from cte_distributed_users where age_group in ('11-20', '21-30')) then 25
            when r.row_num <= (select sum(num_users) from cte_distributed_users where age_group in ('11-20', '21-30', '31-40')) then 35
            when r.row_num <= (select sum(num_users) from cte_distributed_users where age_group in ('11-20', '21-30', '31-40', '41-50')) then 45
            when r.row_num <= (select sum(num_users) from cte_distributed_users where age_group in ('11-20', '21-30', '31-40', '41-50', '51-60')) then 55
            when r.row_num <= (select sum(num_users) from cte_distributed_users where age_group in ('11-20', '21-30', '31-40', '41-50', '51-60', '61-70')) then 65
            else 75
        end as estimated_age
    from ranked_cte_new_users r
)
-- Inserting the new users into the users table
insert into users_cleaned (id, age, birth_date, created_date, state, language, gender)
select 
    user_id, 
    estimated_age,
    current_date - interval '1 year' * a.estimated_age as birth_date,
    created_date,
    'unknown' as state,
    'unknown' as language,
    'unknown' as gender
from cte_assigned_users;

--The above query maintains the distribution

--1. What are the top 5 brands by receipts scanned among users 21 and over?


Select p.brand,count(distinct receipt_id) as total_receipts
from transactions_cleaned t
join users_cleaned u on t.user_id=u.id
join products_cleaned p on p.barcode=t.barcode
where u.age>=21
and p.brand <> 'Unknown'
group by p.brand
order by count(distinct receipt_id) desc
limit 5


/*brand	total_receipts
 COCA-COLA	494
GREAT VALUE	355
PEPSI	340
EQUATE	322
LAY'S	298
*/

-- 3.What is the percentage of sales in the Health & Wellness category by generation?
With cte_total_sales as
(
	Select sum(final_sale) as total_sales
	from transactions_cleaned t
	join products_cleaned p on p.barcode=t.barcode
	where trim(p.category_1)='Health & Wellness'
)
Select 
	case when age <13 then 'Gen Alpha'
			 when age between 13 and 28 then 'Gen Z'
			 when age between 29 and 44 then 'Millennials'
			 when age between 45 and 60 then 'Gen X'
			 when age between 61 and 80 then 'Boomers'
		end as generation,
	sum(t.final_sale) as total_sales,
	round(sum(t.final_sale)*100.00
				/(Select total_sales from cte_total_sales),2) || '%' as percentage_of_total_sales
from transactions_cleaned t
join products_cleaned p on t.barcode=p.barcode
join users_cleaned u on t.user_id=u.id
where trim(p.category_1)='Health & Wellness'
group by generation;

/*generation	total_sales	percentage_of_total_sales
Boomers	1556.56	10.00%
Gen X	5859.48	37.63%
Gen Z	5122.46	32.90%
Millenials	3033.47	19.48%*/


-- Open-ended questions:for these, make assumptions and clearly state them when answering the question.


--2. Which is the leading brand in the Dips & Salsa category?

--Identifying the column(s) that match the category
Select
sum(case when (trim(category_1)) ='Dips & Salsa' then 1 else 0 end) as c1,
sum(case when (trim(category_2)) ='Dips & Salsa' then 1 else 0 end) as c2,
sum(case when (trim(category_3)) ='Dips & Salsa' then 1 else 0 end) as c3,
sum(case when (trim(category_4)) ='Dips & Salsa' then 1 else 0 end) as c4
from products_cleaned pc

--44% of the records for the category have final_sale=0
Select Round(count(t.*)*100.00/(select count(*) from products_cleaned p
						join transactions_cleaned t on p.barcode=t.barcode
						where trim(category_2)='Dips & Salsa'),2)
from products_cleaned p
join transactions_cleaned t on p.barcode=t.barcode
where trim(category_2)='Dips & Salsa'
and t.final_sale =0

--We can consider the total sales value, number of records, unique users to determine the leading brand
--Transactions with final_sale = 0 are assumed to be data ingestion errors —> excluded from revenue calculations but included in total quantity sold to reflect actual product transactions

select 
    p.brand,
    sum(t.final_sale) as total_sale,
    sum(final_quantity) as total_quantity,
    count(*) as total_transactions,
    count(distinct user_id) as unique_users,
    sum(case when t.final_sale = 0 then 1 else 0 end) as transactions_with_zero_sale_value, --percentage of transactions for this brand that have final_quantity=0
    -- analytical ratios
    round((sum(case when t.final_sale = 0 then 1 else 0 end) * 100.0) / count(*),2) as zero_sale_percentage, -- % zero sale transactions
    cast((count(*) * 1.0 / nullif(count(distinct user_id), 0)) as decimal(10,2)) as transactions_per_user -- transaction frequency per user
from products_cleaned p
join transactions_cleaned t on p.barcode = t.barcode
where trim(category_2) = 'Dips & Salsa'
group by p.brand
order by total_sale desc, total_quantity desc, total_transactions desc;

/*
 brand	total_sale	total_quantity	total_transactions	unique_users	transactions_with_zero_sale_value	zero_sale_percentage	transactions_per_user
 TOSTITOS	83.98	38.00	36	35	19	52.78	1.03
MARKETSIDE	53.53	16.00	16	16	3	18.75	1.00
Unknown	53.40	22.00	21	21	12	57.14	1.00
PACE	37.56	24.00	24	24	12	50.00	1.00
GOOD FOODS	36.97	9.00	9	9	6	66.67	1.00
 */

--Final thoughts
--TOSTITOS is the leading brand, ranking highest in both total revenue and quantity sold, making it the top performer in the Dips & Salsa category.
-- While TOSTITOS has minimal repeat buying, all other brands in this category are one-time purchases, with only one transaction per user


--3. At what percent has Fetch grown year over year?
--This would be better answered if I had access to the revenue data.
--Assumption —>Considering Yoy growth in terms of New user acquisition identified by createed_date in users table


Select
	extract(year from created_date) as year,
	count(id) as total_number_of_users,
	round(100.00 * (count(id)-lag(count(id)) over(order by extract(year from created_date)))
			/lag(count(id)) over(order by extract(year from created_date)),2) as yoy_growth
from users_cleaned tu
group by year
order by year

