-- ============================================================
-- 06_BUSINESS_ANALYSIS.SQL
-- Olist Brazilian E-Commerce Analytics
-- ============================================================
-- PURPOSE:
-- Analyze fulfillment performance and customer experience using the order-level analytical model
--
-- PRIMARY THEMES:
--   1. Delivery reliability
--   2. Customer experience
--   3. Geographic variation
--   4. Order economics
--   5. Operational trends
-- ============================================================

USE olist_analytics;

-- ============================================================
-- 1. OVERALL DELIVERY PERFORMANCE
-- How reliably are evaluable orders delivered by the estimated date?
-- ============================================================

SELECT COUNT(*) AS evaluable_orders,
       SUM(on_time_flag = 1) AS on_time_orders,
       SUM(on_time_flag = 0) AS late_orders,
       ROUND(((SUM(on_time_flag = 1) / COUNT(*)) * 100), 2) AS on_time_rate_pct,
       ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
       ROUND(AVG(delivery_variance_days), 2) AS avg_delivery_variance_days
FROM view_order_analysis
WHERE on_time_flag IS NOT NULL;

-- FINDING:
-- 93.23% of 96,476 orders with sufficient delivery information were delivered on/before the estimated delivery date
-- Orders took ~12.09 days from purchase to delivery on average, arrived ~11.88 calendar days ahead of the estimated date on average

-- ============================================================
-- 2. LATE-DELIVERY SEVERITY
-- How severe are late orders?
-- ============================================================

SELECT COUNT(*) AS late_orders,
       ROUND(AVG(delivery_variance_days), 2) AS avg_days_late,
       MIN(delivery_variance_days) AS min_days_late,
       MAX(delivery_variance_days) AS max_days_late
FROM view_order_analysis
WHERE delivery_variance_days > 0;

-- FINDING:
-- 6,535 orders were delivered late
-- Late orders arrived 10.62 days late on average, with observed lateness ranging from 1 to 188 days

-- ============================================================
-- 3. DELIVERY & REVIEWS
-- How do customer review scores differ between on-time and late orders?
-- ============================================================

SELECT
    CASE
        WHEN on_time_flag = 1 THEN 'On time'
        WHEN on_time_flag = 0 THEN 'Late'
    END AS delivery_status,
    COUNT(review_score) AS reviewed_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM view_order_analysis
WHERE on_time_flag IS NOT NULL
  AND review_score IS NOT NULL
GROUP BY 1
ORDER BY 1 DESC;

-- FINDING:
-- Orders delivered on time had an average review score of 4.29, while late orders had an average score of 2.27 (2.02 points difference)
-- -> strong association between delivery performance and customer satisfaction, but does not establish that lateness causes lower review scores

-- ============================================================
-- 4. LATENESS SEVERITY & CUSTOMER REVIEWS
-- How does customer review score vary with the severity of lateness?
-- ============================================================

SELECT
    CASE
        WHEN delivery_variance_days < 0 THEN 'Early'
        WHEN delivery_variance_days = 0 THEN 'On time'
        WHEN delivery_variance_days BETWEEN 1 AND 3 THEN '1-3 days late'
        WHEN delivery_variance_days BETWEEN 4 AND 7 THEN '4-7 days late'
        WHEN delivery_variance_days BETWEEN 8 AND 14 THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delivery_performance,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM view_order_analysis
WHERE delivery_variance_days IS NOT NULL
  AND review_score IS NOT NULL
GROUP BY 1
ORDER BY MIN(delivery_variance_days);

-- FINDING:
-- Customer review scores decline substantially as delivery performance worsens
-- -> a strong association between greater delivery lateness and lower customer review scores, but does not establish causality

-- ============================================================
-- 5. DELIVERY PERFORMANCE BY CUSTOMER STATE
-- How does fulfillment performance vary across customer states?
-- ============================================================

SELECT customer_state,
       COUNT(*) AS evaluable_orders,
       ROUND((AVG(on_time_flag) * 100), 2) AS on_time_rate_pct,
       ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
       ROUND(AVG(review_score), 2) AS avg_review_score
FROM view_order_analysis
WHERE on_time_flag IS NOT NULL
GROUP BY customer_state
ORDER BY on_time_rate_pct ASC;

-- FINDING:
-- Fulfillment performance varies substantially across customer states
-- State-level results should be interpreted alongside order volume because several states have relatively small numbers of evaluable orders

-- ============================================================
-- 6. MONTHLY ORDER AND FULFILLMENT TRENDS
-- How did order volume and fulfillment performance change over time?
-- ============================================================

SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
       COUNT(*) AS fulfillment_evaluable_orders,
       ROUND((AVG(on_time_flag) * 100), 2) AS on_time_rate_pct,
       ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
       ROUND(AVG(review_score), 2) AS avg_review_score
FROM view_order_analysis
WHERE on_time_flag IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY 1
ORDER BY 1;

-- FINDING:
-- Fulfillment performance varied significantly over time
-- On-time performance weakened in late 2017 and early 2018, reaching as low as 81.04% in March 2018, 
-- which was also the month with the lowest observed at 3.81
-- Performance subsequently improved: the on-time rate recovered to 95.50% in April 2018 and reached 98.84% in June, 
-- while average delivery time also declined substantially

-- ============================================================
-- 7. FREIGHT BURDEN BY CUSTOMER STATE
-- How does freight cost relative to merchandise value vary by state?
-- ============================================================

SELECT customer_state,
       COUNT(*) AS orders,
       ROUND(AVG(merchandise_value), 2) AS avg_merchandise_value,
       ROUND(AVG(freight_value), 2) AS avg_freight_value,
       ROUND(((SUM(freight_value) / SUM(merchandise_value)) * 100), 2) AS freight_to_merchandise_pct
FROM view_order_analysis
WHERE merchandise_value IS NOT NULL
GROUP BY customer_state
ORDER BY 5 DESC;

-- FINDING:
-- Freight cost relative to merchandise value varies considerably across customer states
-- E.g., MA had freight equal to 26.35% of merchandise value, compared with 13.81% in SP, the largest market by order count
-- Geographic freight comparisons should be interpreted alongside order volume because several states have relatively small samples





