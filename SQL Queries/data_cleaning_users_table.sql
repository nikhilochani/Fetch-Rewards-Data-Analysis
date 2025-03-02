----Users----
--This script involves the users table cleaning process along with a detailed thought process

--Data understanding
/*
 1. No duplicates
 2. No null ids_>Meaning every record represents a unique user
 3. Birthdate column is a timestamp —>Weirdly(professional appropriate word)
 4. 4% birthdate nulls (Check again after adding users from transactions table)
 Preprocessing
 1. Creating new column age
 2. Updating gender nulls (6%) with "Unknown" and standardize the duplicate values with the same meaning
	 	1. male
		2. female
		3. transgender
		4. non_binary (mapping "Non-Binary") 
		5. not_listed (mapping My gender isn't listed)
		6. prefer_not_to_say (mapping values for->"Prefer not to say") --Could be useful later or should I merge with unknown?
		7. unknown (mapping values for->not_specified, nulls)
 */

SELECT 
    count(*) as total_rows,
    sum(Case when id is null or id='' then 1 else 0 end) || '' as id,
    sum(Case when created_date is null then 1 else 0 end) || '' as created_date,
    sum(Case when birth_date is null then 1 else 0 end) || '' as birth_date,
    sum(Case when state is null or state='' then 1 else 0 end) || '' as state,
    sum(Case when language is null or language='' then 1 else 0 end) || '' as language,
    sum(Case when gender is null or gender=''  then 1 else 0 end) || '' as gender
FROM temp_users
UNION ALL
SELECT 
    count(*)*100.00/count(*) as total_rows,
    round(sum(Case when id is null or id='' then 1 else 0 end)*100.00/count(*)) || '%' as id,
    round(sum(Case when created_date is null then 1 else 0 end)*100.00/count(*))|| '%' as created_date,
    round(sum(Case when birth_date is null then 1 else 0 end)*100.00/count(*)) || '%' as birth_date,
    round(sum(Case when state is null or state='' then 1 else 0 end)*100.00/count(*)) || '%' as state,
    round(sum(Case when language is null or language='' then 1 else 0 end)*100.00/count(*)) || '%' as language,
    round(sum(Case when gender is null or gender=''  then 1 else 0 end)*100.00/count(*)) || '%' as gender
FROM temp_users;


--Adding age and birthdate columns
Alter table temp_users add column age int;
Alter table temp_users add column birth_date_updated date;

--Cleaning the columns
Update temp_users
Set birth_date_updated=date(birth_date),
	age=extract(year from (age(current_date,date(birth_date)))),
	gender=case 
				when lower(trim(gender))='female' then 'female'
				when lower(trim(gender))='male' then 'male'
				when lower(trim(gender))='transgender' then 'transgender'
				when lower(trim(gender))='non_binary' or lower(trim(gender))='non-binary' then 'non_binary'
				when lower(trim(gender))='prefer_not_to_say' or lower(trim(gender)) like 'prefer not to say' then 'prefer_not_to_say'
				when lower(trim(gender))='not_listed' or lower(trim(gender)) like '%listed' then 'not_specified'
				when lower(trim(gender))='unknown' or lower(trim(gender))='not_specified' or gender is null or gender='' then 'unknown'
			end,
	state=case
			when trim(state)='' or state is null then 'Unknown'
			else trim(state)
		  end,
	language=case 
				when language='' then 'Unknown'
				else trim(language)
			end;

commit;

Select *from temp_users tu 


Create Table users_cleaned (
    id Varchar PRIMARY KEY,
    created_date Timestamp NOT NULL,
    birth_date date,
    state Varchar,
    language Varchar,
    gender Varchar,
    age int
);
commit;

Insert into users_cleaned
Select 
	id as id,
	created_date as created_date,
	birth_date_updated as birth_date,
	state as state,
	language as language,
	gender as gender,
	age as age
from temp_users;
commit;


--Handling missing data and outliers for age column
Update users_cleaned_copy
set age = case 
    when age is null then 39  -- Assigning median age
    when age > 80 then 80     -- Cap age at 80
    when age < 10 then 10     -- Set minimum reasonable age
    else age 
end
where id in (
    select distinct user_id 
    from transactions_cleaned 
    where user_id in (select id from users_cleaned_copy where age is null or age < 10 or age > 80)
);
commit;

