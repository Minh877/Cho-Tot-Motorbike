/*
COHORT ANALYSIS & USER SEGMENTATION

Description: 

Paytm is an Indian multinational financial technology company.
It specializes in digital payment system, e-commerce and financial services.
Paytm wallet is a secure and RBI (Reserve Bank of India)-approved digital/mobile wallet
that provides a myriad of financial features to fulfill every consumer’s payment needs.
Paytm wallet can be topped up through UPI (Unified Payments Interface), internet banking, or credit/debit cards.
Users can also transfer money from a Paytm wallet to recipient’s bank account or their own Paytm wallet. 

Below is a small database of payment transactions from 2019 to 2020 of Paytm Wallet. The database includes 6 tables: 
•	fact_transaction: Store information of all types of transactions: Payments, Top-up, Transfers, Withdrawals
•	dim_scenario: Detailed description of transaction types
•	dim_payment_channel: Detailed description of payment methods
•	dim_platform: Detailed description of payment devices
•	dim_status: Detailed description of the results of the transaction
*/
SELECT top 5 * FROM fact_transaction_2019
SELECT top 5 * FROM dim_scenario
SELECT top 5 * FROM dim_payment_channel
SELECT top 5 * FROM dim_platform
SELECT top 5 * FROM dim_status

/*
COHORT ANALYSIS METHODS

1. Retention:
    1.1. Basic Retention Curve:
    Task: 
    A. As you know that 'Telco Card' is the most product in the Telco group (accounting for more than 99% of the total).
    You want to evaluate the quality of user acquisition in Jan 2019 by the retention metric.
    First, you need to know how many users are retained in each subsequent month from the first month (Jan 2019)
    they pay the successful transaction (only get data of 2019). 
*/
-- Code here
WITH period_table as (
    SELECT customer_id
        , transaction_id
        , transaction_time
        , MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time) as first_time
        , DATEDIFF(month, MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time), transaction_time) as subsequent_month
    FROM fact_transaction_2019 as fact_19
    JOIN dim_scenario as scen
        ON fact_19.scenario_id = scen.scenario_id
    WHERE scen.sub_category = 'Telco Card'
        AND fact_19.status_id = 1
)

SELECT subsequent_month
    , COUNT(DISTINCT customer_id) as retained_users
FROM period_table
WHERE MONTH(first_time) = 1
GROUP BY subsequent_month

/*
    B. You realize that the number of retained customers has decreased over time.
    Let’s calculate retention =  number of retained customers / total users of the first month. 
*/	 
-- Code here
WITH period_table as (
    SELECT customer_id
        , transaction_id
        , transaction_time
        , MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time) as first_time
        , DATEDIFF(month, MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time), transaction_time) as subsequent_month
    FROM fact_transaction_2019 as fact_19
    JOIN dim_scenario as scen
        ON fact_19.scenario_id = scen.scenario_id
    WHERE scen.sub_category = 'Telco Card'
        AND fact_19.status_id = 1
)
, jan_19_retention_table as (
    SELECT subsequent_month
        , COUNT(DISTINCT customer_id) as retained_users
    FROM period_table
    WHERE MONTH(first_time) = 1
    GROUP BY subsequent_month
)

SELECT *
    , FIRST_VALUE(retained_users) OVER(ORDER BY subsequent_month) as original_users
    , FORMAT(1.0 * retained_users / FIRST_VALUE(retained_users) OVER(ORDER BY subsequent_month), 'p') as pct_retained_users
FROM jan_19_retention_table

/*
    1.2. Cohorts Derived from the Time Series Itself
    Task: Expend your previous query to calculate retention for multi attributes from the acquisition month (from Jan to December). 
*/	 
-- Code here
WITH period_table as (
    SELECT customer_id
        , transaction_id
        , transaction_time
        , MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time) as first_time
        , DATEDIFF(month, MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time), transaction_time) as subsequent_month
    FROM fact_transaction_2019 as fact_19
    JOIN dim_scenario as scen
        ON fact_19.scenario_id = scen.scenario_id
    WHERE scen.sub_category = 'Telco Card'
        AND fact_19.status_id = 1
)
, jan_19_retention_table as (
    SELECT MONTH(first_time) as acquisition_month
        , subsequent_month
        , COUNT(DISTINCT customer_id) as retained_users
    FROM period_table
    GROUP BY MONTH(first_time), subsequent_month
)

SELECT *
    , FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month) as original_users
    , FORMAT(1.0 * retained_users / FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month), 'p') as pct_retained_users
FROM jan_19_retention_table

-- Transform the result to PIVOT TABLE:
WITH period_table as (
    SELECT customer_id
        , transaction_id
        , transaction_time
        , MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time) as first_time
        , DATEDIFF(month, MIN(transaction_time) OVER(PARTITION BY customer_id ORDER BY transaction_time), transaction_time) as subsequent_month
    FROM fact_transaction_2019 as fact_19
    JOIN dim_scenario as scen
        ON fact_19.scenario_id = scen.scenario_id
    WHERE scen.sub_category = 'Telco Card'
        AND fact_19.status_id = 1
)
, retention_table as (
    SELECT MONTH(first_time) as acquisition_month
        , subsequent_month
        , COUNT(DISTINCT customer_id) as retained_users
    FROM period_table
    GROUP BY MONTH(first_time), subsequent_month
)
, acquisition_table as (
    SELECT *
        , FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month) as original_users
        , FORMAT(1.0 * retained_users / FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month), 'p') as pct_retained_users
    FROM retention_table
)

SELECT acquisition_month
    , original_users
    , "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"
FROM (
    SELECT acquisition_month, original_users, subsequent_month, pct_retained_users
    FROM acquisition_table
) as table_source
PIVOT (
    MIN(pct_retained_users)
    FOR subsequent_month IN ("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11")
) as pivot_table
ORDER BY acquisition_month

/*
USER SEGMENTATION
    RFM Segmentation
*/
-- Code here
WITH fact_table as (
    SELECT fact_19.* FROM fact_transaction_2019 as fact_19
    LEFT JOIN dim_scenario as scen
        ON fact_19.scenario_id = scen.scenario_id
    WHERE scen.sub_category = 'Telco Card'
        AND fact_19.status_id = 1
    UNION
    SELECT fact_20.* FROM fact_transaction_2020 as fact_20
    LEFT JOIN dim_scenario as scen
        ON fact_20.scenario_id = scen.scenario_id
    WHERE scen.sub_category = 'Telco Card'
        AND fact_20.status_id = 1
)
-- Assign Recency, Frequency and Monetary values to each customer.
, rfm_table as (
    SELECT customer_id
        , DATEDIFF(day, MAX(transaction_time), '2020-12-31') as Recency
        , COUNT(DISTINCT FORMAT(transaction_time, 'yyyy-mm-dd')) as Frequency
        , SUM(charged_amount) as Monetary
    FROM fact_table
    GROUP BY customer_id
)
-- Divide the customer list into tiered groups for each of the three dimensions (R, F and M).
, rfm_rank_table as (
    SELECT customer_id
        , PERCENT_RANK() OVER(ORDER BY Recency ASC) as r_rank
        , PERCENT_RANK() OVER(ORDER BY Frequency DESC) as f_rank
        , PERCENT_RANK() OVER(ORDER BY Monetary DESC) as m_rank
    FROM rfm_table
)
, rfm_score_table as (
    SELECT *
        , CASE
            WHEN r_rank > 0.75 THEN 4
            WHEN r_rank > 0.5 THEN 3
            WHEN r_rank > 0.25 THEN 2
            ELSE 1
        END as r_score
        , CASE
            WHEN f_rank > 0.75 THEN 4
            WHEN f_rank > 0.5 THEN 3
            WHEN f_rank > 0.25 THEN 2
            ELSE 1
        END as f_score
        , CASE
            WHEN m_rank > 0.75 THEN 4
            WHEN m_rank > 0.5 THEN 3
            WHEN m_rank > 0.25 THEN 2
            ELSE 1
        END as m_score
    FROM rfm_rank_table
)
-- Group of customers
, segmentation_table as (
    SELECT customer_id
        , r_score, f_score, m_score
        , CASE
            WHEN CONCAT(r_score,f_score, m_score) = 111 THEN 'Best Customers'
            WHEN CONCAT(r_score,f_score, m_score) LIKE '[3-4][3-4][1-4]' THEN 'Lost Bad Customers'
            WHEN CONCAT(r_score,f_score, m_score) LIKE '[3-4]2[1-4]' THEN 'Lost Customers'
            WHEN CONCAT(r_score,f_score, m_score) LIKE  '21[1-4]' THEN 'Almost Lost'
            WHEN CONCAT(r_score,f_score, m_score) LIKE  '11[2-4]' THEN 'Loyal Customers'
            WHEN CONCAT(r_score,f_score, m_score) LIKE  '[1-2][1-3]1' THEN 'Big Spenders'
            WHEN CONCAT(r_score,f_score, m_score) LIKE  '14[1-4]' THEN 'New Customers'
            WHEN CONCAT(r_score,f_score, m_score) LIKE  '[3-4]1[1-4]' THEN 'Hibernating'
            WHEN CONCAT(r_score,f_score, m_score) LIKE  '[1-2][2-3][2-4]' THEN 'Potential Loyalists'
            ELSE 'unknown'
        END AS segment
    FROM rfm_score_table
)

SELECT segment
    , COUNT(customer_id) as num_users
    , FORMAT(1.0 * COUNT(customer_id) / SUM(COUNT(customer_id)) OVER(), 'p') as pct
FROM segmentation_table
GROUP BY segment
ORDER BY num_users DESC

/*
    •	Best Customers – This group consists of those customers who are found in R-Tier-1, F-Tier-1 and M-Tier-1, meaning that they transacted recently,
    do so often and spend more than other customers. A shortened notation for this segment is 1-1-1; we’ll use this notation going forward.
    •	Lost Bad Customers – This group consists of those customers in R-Tier-3-4 and F-Tier-3-4.
    These are customers who transacted only once, and rarely come back.
    •	Lost Customers – This group consists of those customers in R-Tier-3-4 and F-Tier-2.
    These are customers who transacted so often, but it’s been a long time since they’ve transacted.
    •	Almost Lost – This group consists of those customers in R-Tier-2 and F-Tier-1.
    These are customers who transacted frequently, but recently they do not.
    •	Loyal Customers - This group consists of those customers in segments 1-1-2, 1-1-3 and 1-1-4.
    These are customers who transacted recently and do so often, but spend the least.
    •	Big Spenders – This group consists of those customers in R-Tier-1-2, F-Tier-1-3 and M-Tier-1.
    These are customers who transacted recently and do so often, but spend a lot.
    •	New Customers – This group consists of those customers in R-Tier-1 and F-Tier-4.
    These are customers who transacted only once, but very recently.
*/
