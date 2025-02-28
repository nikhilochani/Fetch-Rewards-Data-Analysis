# Email to stakeholder

### Sub: Data Quality Findings and Questions

Hi [Stakeholder Name],

I’ve been reviewing our transactions, users, and product data and noticed a few inconsistencies that may impact analysis. Below are some key findings, and I’d appreciate your insights on a few open questions.

#### Data Quality Concerns:
1. **Missing Users in Transactions:** 99.48% of users in the transactions table are not present in the users table. Are these records stored elsewhere, or is there a known gap in data integration?

2. **Final Quantity Tracking:** Many transactions, particularly from grocery stores, have final_quantity values between 0 and 1, which suggests weight-based tracking. However, similar patterns also appear in non-grocery items like snacks, raising questions about standardization. How is final_quantity determined across different product types?

3. **Transaction Data Issues:** A portion of the data contains missing barcodes, duplicate entries, and conflicting values for final_quantity and final_sale, making some records unusable. There are also transactions where purchase dates occur after scan dates, raising concerns about data capture accuracy. Could this indicate pipeline issues, scanning inconsistencies, or something else?

#### YOY User Acquisition Decline:
Fetch’s year-over-year user acquisition grew strongly through 2020 but declined sharply in 2023 (-42%) and 2024 (-24%). Since transaction users don’t appear in the users table, the growth trend may be underestimated.

#### Additional Information:
4. Would it be possible to get access to any documentation on how user records, transactions, and barcodes are processed?
5. Lastly, is there a way to access revenue data to analyze YOY growth in terms of revenue?

Let me know if you have any insights or if we should set up time to discuss. Looking forward to hearing from you.

Best,  
Nikhil
