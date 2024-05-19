/*
TIME SERIES ANALYSIS

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
TIME SERIES ANALYSIS METHODS

1. Trending the Data:
    1.1. Simple trend
    Task: You need to analyze the trend of payment transactions of Billing category from 2019 to 2020.
    First, let’s show the trend of the number of successful transaction by month. 
*/
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)

SELECT YEAR(transaction_time) as Year
    , MONTH(transaction_time) as Month
    , COUNT(transaction_id) as num_trans
FROM fact_table
LEFT JOIN dim_scenario as scen
    ON fact_table.scenario_id = scen.scenario_id
WHERE scen.category = 'Billing'
    AND status_id = 1
GROUP BY YEAR(transaction_time)
    , MONTH(transaction_time)
ORDER BY [Year], [Month]

/*
    1.2. Comparing Component
    Task: You know that, there are many sub-categories of Billing group.
    After reviewing the above result, you should break down the trend into each sub-categories.
*/
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)

SELECT YEAR(transaction_time) as Year
    , MONTH(transaction_time) as Month
    , scen.sub_category
    , COUNT(transaction_id) as num_trans
FROM fact_table
LEFT JOIN dim_scenario as scen
    ON fact_table.scenario_id = scen.scenario_id
WHERE scen.category = 'Billing'
    AND status_id = 1
GROUP BY YEAR(transaction_time)
    , MONTH(transaction_time)
    , scen.sub_category
ORDER BY [Year], [Month], sub_category

/*
    Then modify the result: Only select the sub-categories belong to list (Electricity, Internet and Water)
*/
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)
, sub_cat_table as (
    SELECT YEAR(transaction_time) as Year
        , MONTH(transaction_time) as Month
        , scen.sub_category
        , COUNT(transaction_id) as num_trans
    FROM fact_table
    LEFT JOIN dim_scenario as scen
        ON fact_table.scenario_id = scen.scenario_id
    WHERE scen.category = 'Billing'
        AND status_id = 1
    GROUP BY YEAR(transaction_time)
        , MONTH(transaction_time)
        , scen.sub_category
)

SELECT [Year], [Month]
    , SUM(CASE WHEN sub_category = 'Electricity' THEN num_trans END) as Electricity_trans
    , SUM(CASE WHEN sub_category = 'Internet' THEN num_trans END) as Internet_trans
    , SUM(CASE WHEN sub_category = 'Water' THEN num_trans END) as Water_trans
FROM sub_cat_table
GROUP BY [Year], [Month]
ORDER BY [Year], [Month]

/*
    1.3. Percent of Total Calculations:
    Task: Based on the previous query, you need to calculate the proportion of each sub-category
    (Electricity, Internet and Water) in the total for each month.
*/
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)
, sub_cat_table as (
    SELECT YEAR(transaction_time) as Year
        , MONTH(transaction_time) as Month
        , scen.sub_category
        , COUNT(transaction_id) as num_trans
    FROM fact_table
    LEFT JOIN dim_scenario as scen
        ON fact_table.scenario_id = scen.scenario_id
    WHERE scen.category = 'Billing'
        AND status_id = 1
    GROUP BY YEAR(transaction_time)
        , MONTH(transaction_time)
        , scen.sub_category
)
, sub_cat_table_2 as (
    SELECT [Year], [Month]
        , SUM(CASE WHEN sub_category = 'Electricity' THEN num_trans END) as Electricity_trans
        , SUM(CASE WHEN sub_category = 'Internet' THEN num_trans END) as Internet_trans
        , SUM(CASE WHEN sub_category = 'Water' THEN num_trans END) as Water_trans
    FROM sub_cat_table
    GROUP BY [Year], [Month]
)
SELECT *
    , ISNULL(Electricity_trans, 0) + ISNULL(Internet_trans, 0) + ISNULL(Water_trans, 0) as total_trans_month
    , FORMAT(1.0 * Electricity_trans / (ISNULL(Electricity_trans, 0) + ISNULL(Internet_trans, 0) + ISNULL(Water_trans, 0)), 'p') as electricity_trans_pct
    , FORMAT(1.0 * Internet_trans / (ISNULL(Electricity_trans, 0) + ISNULL(Internet_trans, 0) + ISNULL(Water_trans, 0)), 'p') as internet_trans_pct
    , FORMAT(1.0 * Water_trans / (ISNULL(Electricity_trans, 0) + ISNULL(Internet_trans, 0) + ISNULL(Water_trans, 0)), 'p') as water_trans_pct
FROM sub_cat_table_2
ORDER BY [Year], [Month]

/*
    1.4. Indexing to See Percent Change over Time:
    Task: Select only these sub-categories in the list (Electricity, Internet and Water),
    you need to calculate the number of successful paying customers for each month (from 2019 to 2020).
    Then find the percentage change from the first month (Jan 2019) for each subsequent month.
*/ 
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)
, sub_cat_table as (
    SELECT YEAR(transaction_time) as Year
        , MONTH(transaction_time) as Month
        , COUNT(DISTINCT customer_id) as num_customers
    FROM fact_table
    LEFT JOIN dim_scenario as scen
        ON fact_table.scenario_id = scen.scenario_id
    WHERE scen.category = 'Billing'
        AND scen.sub_category IN ('Electricity', 'Internet', 'Water')
        AND status_id = 1
    GROUP BY YEAR(transaction_time)
        , MONTH(transaction_time)
)

SELECT *
    , FIRST_VALUE(num_customers) OVER(ORDER BY [Year], [Month]) as starting_point
    , FORMAT((1.0 * num_customers / FIRST_VALUE(num_customers) OVER(ORDER BY [Year], [Month])) - 1, 'p') as pct_from_starting_point
FROM sub_cat_table
ORDER BY [Year], [Month]

/*
2. Rolling Time Windows:
    2.1. Calculating Rolling Time Windows
    Task: Select only these sub-categories in the list (Electricity, Internet and Water),
    you need to calculate the number of successful paying customers for each week number from 2019 to 2020).
    Then get rolling annual paying users of this group. 
*/
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)
, sub_cat_table as (
    SELECT YEAR(transaction_time) as Year
        , DATEPART(Week, transaction_time) as Week
        , CONCAT(YEAR(transaction_time), '-', DATEPART(Week, transaction_time)) as calendar
        , COUNT(DISTINCT customer_id) as num_customers
    FROM fact_table
    LEFT JOIN dim_scenario as scen
        ON fact_table.scenario_id = scen.scenario_id
    WHERE scen.category = 'Billing'
        AND scen.sub_category IN ('Electricity', 'Internet', 'Water')
        AND status_id = 1
    GROUP BY YEAR(transaction_time)
        , DATEPART(Week, transaction_time)
        , CONCAT(YEAR(transaction_time), '-', DATEPART(Week, transaction_time))
)

SELECT *
    , SUM(num_customers) OVER(PARTITION BY [Year] ORDER BY [Week]) as rolling_num_customers
FROM sub_cat_table
ORDER BY [Year], [Week]

/*
    2.2. Moving average 
    Task: Based on the previous query, calculate the average number of customers for the last 4 weeks in each observation week.
    Then compare the difference between the current value and the average value of the last 4 weeks.
*/
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)
, sub_cat_table as (
    SELECT YEAR(transaction_time) as Year
        , DATEPART(Week, transaction_time) as Week
        , CONCAT(YEAR(transaction_time), '-', DATEPART(Week, transaction_time)) as calendar
        , COUNT(DISTINCT customer_id) as num_customers
    FROM fact_table
    LEFT JOIN dim_scenario as scen
        ON fact_table.scenario_id = scen.scenario_id
    WHERE scen.category = 'Billing'
        AND scen.sub_category IN ('Electricity', 'Internet', 'Water')
        AND status_id = 1
    GROUP BY YEAR(transaction_time)
        , DATEPART(Week, transaction_time)
        , CONCAT(YEAR(transaction_time), '-', DATEPART(Week, transaction_time))
)
, rolling_customers_table as (
    SELECT *
        , SUM(num_customers) OVER(PARTITION BY [Year] ORDER BY [Week]) as rolling_num_customers
    FROM sub_cat_table
)

SELECT *
    , AVG(num_customers) OVER(PARTITION BY [Year] ORDER BY [Week] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) as moving_avg
    , num_customers - AVG(num_customers) OVER(PARTITION BY [Year] ORDER BY [Week] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) as difference_avg
FROM rolling_customers_table

/*
3. Analyzing with Seasonality:
    Period-over-Period Comparisons: YoY and MoM 
    Task: Based on the query 2.1, calculate the growth rate of the number of users by month compared to the same period last year. 
*/
-- Code here
WITH fact_table as (
    SELECT * FROM fact_transaction_2019
    UNION
    SELECT * FROM fact_transaction_2020
)
, sub_cat_table as (
    SELECT YEAR(transaction_time) as Year
        , MONTH(transaction_time) as Month
        , COUNT(DISTINCT customer_id) as num_customers
    FROM fact_table
    LEFT JOIN dim_scenario as scen
        ON fact_table.scenario_id = scen.scenario_id
    WHERE scen.category = 'Billing'
        AND scen.sub_category IN ('Electricity', 'Internet', 'Water')
        AND status_id = 1
    GROUP BY YEAR(transaction_time)
        , MONTH(transaction_time)
)

SELECT *
    , LAG(num_customers, 12, num_customers) OVER(ORDER BY Year, Month) as last_period
    , FORMAT(1.0 * num_customers / LAG(num_customers, 12, num_customers) OVER(ORDER BY Year, Month), 'p') as MoM
FROM sub_cat_table
ORDER BY [Year], [Month]
