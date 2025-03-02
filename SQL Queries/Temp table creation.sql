--Creating staging/temp Tables to proceed with data preprocessing

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