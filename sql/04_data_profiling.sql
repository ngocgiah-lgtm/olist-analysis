USE olist_analytics;

-- =========================================================================================
-- 1. SOURCE RECONCILIATION, GRAIN & KEY INTEGRITY
-- Purpose: Validate source completeness and confirm the intended grain and uniqueness of each table before analysis
-- =========================================================================================

SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count FROM raw_customers
UNION ALL
SELECT 'raw_orders', COUNT(*) FROM raw_orders
UNION ALL
SELECT 'raw_order_items', COUNT(*) FROM raw_order_items
UNION ALL
SELECT 'raw_products', COUNT(*) FROM raw_products
UNION ALL
SELECT 'raw_sellers', COUNT(*) FROM raw_sellers
UNION ALL
SELECT 'raw_payments', COUNT(*) FROM raw_payments
UNION ALL
SELECT 'raw_reviews', COUNT(*) FROM raw_reviews
UNION ALL
SELECT 'raw_geolocation', COUNT(*) FROM raw_geolocation
UNION ALL
SELECT 'raw_product_category_name_translation', COUNT(*)
FROM raw_product_category_name_translation;

-- FINDING:
-- All 9 MySQL raw tables reconcile to their respective source
-- CSV row counts, indicating complete source ingestion

SELECT 'raw_customers.customer_id' AS key_test,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS distinct_keys,
       (COUNT(*) - COUNT(DISTINCT customer_id)) AS duplicate_keys
FROM raw_customers

UNION ALL

SELECT 'raw_orders.order_id',
       COUNT(*),
       COUNT(DISTINCT order_id),
       (COUNT(*) - COUNT(DISTINCT order_id))
FROM raw_orders

UNION ALL

SELECT 'raw_products.product_id',
       COUNT(*),
       COUNT(DISTINCT product_id),
       (COUNT(*) - COUNT(DISTINCT product_id))
FROM raw_products

UNION ALL

SELECT 'raw_sellers.order_id',
       COUNT(*),
       COUNT(DISTINCT seller_id),
       (COUNT(*) - COUNT(DISTINCT seller_id))
FROM raw_sellers

UNION ALL

SELECT 'raw_product_category_name_translation.product_category_name',
       COUNT(*),
       COUNT(DISTINCT product_category_name),
       (COUNT(*) - COUNT(DISTINCT product_category_name))
FROM raw_product_category_name_translation;

-- FINDING
-- No duplicates
-- Validate single-column primary keys

SELECT 'order_items' AS table_name,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id, order_item_id) AS distinct_composite_key,
       (COUNT(*) - COUNT(DISTINCT order_id, order_item_id)) AS duplicate_keys
FROM raw_order_items

UNION ALL

SELECT 'payments',
       COUNT(*),
       COUNT(DISTINCT order_id, payment_sequential),
       (COUNT(*) - COUNT(DISTINCT order_id, payment_sequential))
FROM raw_payments

UNION ALL

SELECT 'reviews',
       COUNT(*),
       COUNT(DISTINCT review_id, order_id),
       (COUNT(*) - COUNT(DISTINCT review_id, order_id))
FROM raw_reviews;

-- FINDING
-- No duplicates
-- Validate composite keys

SELECT COUNT(*) AS customer_records,
       COUNT(DISTINCT customer_id) AS distinct_customer_ids,
       COUNT(DISTINCT customer_unique_id) AS distinct_unique_customers
FROM raw_customers;

SELECT customer_unique_id,
       COUNT(*) AS customer_records
FROM raw_customers
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY 2 DESC;

-- FINDING:
-- customer_id uniquely identifies each customer record
-- while customer_unique_id can repeat across records and identifies the
-- same underlying customer across multiple orders.
--
-- ANALYTICAL IMPLICATION:
-- Use customer_unique_id, not customer_id, when measuring unique customers,
-- repeat purchasing, or customer-level behavior across orders

SELECT COUNT(*) AS geolocation_rows,
       COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes,
       ROUND((COUNT(*) / COUNT(DISTINCT geolocation_zip_code_prefix)),2) AS avg_rows_per_zip_code
FROM raw_geolocation;

SELECT geolocation_zip_code_prefix,
       COUNT(*) AS eolocation_records
FROM raw_geolocation
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- MODELING NOTE:
-- geolocation_zip_code_prefix: not unique in the raw geolocation table
-- -> raw_geolocation should not be joined directly to customers or sellers
-- for aggregated analysis, as doing so could multiply rows and distort results
--
-- FOLLOW-UP:
-- Investigate coordinate and city/state variation within ZIP prefixes
-- Geographic analysis: create a one-row-per-ZIP-prefix before joining geography to other data

-- =========================================================================================
-- 2. MISSINGNESS & DATA COMPLETENESS
-- Purpose: Identify missing information, distinguish expected business-process missingness
-- from potential data-quality issues, and assess implications for downstream analysis
-- =========================================================================================

-- Missing order timestamps:
SELECT COUNT(*) AS total_orders,
       SUM(order_approved_at IS NULL) AS missing_approval,
       SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_delivery,
       SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery
FROM raw_orders;

SELECT order_status,
       COUNT(*) AS total_orders,
       SUM(order_approved_at IS NULL) AS missing_approval,
       SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_delivery,
       SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery
FROM raw_orders
GROUP BY 1
ORDER BY 2 DESC;

-- FINDING:
-- Missing  timestamps are overwhelmingly associated with orders that had not reached the corresponding fulfillment stage
-- This suggests most timestamp missingness reflects order lifecycle status rather than random data loss
--
-- DATA QUALITY NOTE:
-- A small number of delivered orders contain unexpected missing timestamps:
-- 14 lack approval timestamps, 2 lack carrier delivery timestamps, 8 lack customer delivery timestamps
-- These records should be investigated before delivery-time/fulfillment-performance metrics are defined

-- Inspect delivered orders with unexpected missing lifecycle timestamps.
SELECT *
FROM raw_orders
WHERE order_status = 'delivered'
  AND (order_approved_at IS NULL
       OR order_delivered_carrier_date IS NULL
       OR order_delivered_customer_date IS NULL
  )
ORDER BY order_purchase_timestamp;

-- DATA QUALITY NOTE:
-- Missing approval timestamps are notably clustered around February 2017, while other delivered orders lack carrier-delivery or customer-delivery
-- timestamps despite being marked as delivered. This suggests limited source-system/event-capture gaps rather than normal lifecycle missingness.
--
-- ANALYTICAL IMPLICATION:
-- Fulfillment-duration metrics should use only records containing the timestamps required for the specific metric
-- The number of excluded delivered orders should be documented

-- Missing product descriptions:
SELECT COUNT(*) AS total_products,
       SUM(product_category_name IS NULL) AS missing_category,
       SUM(product_name_lenght IS NULL) AS missing_name_length,
       SUM(product_description_lenght IS NULL) AS missing_description_length,
       SUM(product_photos_qty IS NULL) AS missing_photo_qty,
       SUM(product_weight_g IS NULL) AS missing_weight,
       SUM(product_length_cm IS NULL) AS missing_length,
       SUM(product_height_cm IS NULL) AS missing_height,
       SUM(product_width_cm IS NULL) AS missing_width
FROM raw_products;

-- FINDING:
-- Product metadata is highly complete overall: 610 of 32,951 products simultaneously lack category, name-length, description-length, and photo-quantity metadata
-- -> a systematic metadata gap rather than independent missingness across these fields.
-- Physical attributes are nearly complete: only 2 products lack weight and dimensional data.

-- Reviews:
SELECT COUNT(*) AS total_reviews,
       SUM(review_comment_title IS NULL) AS missing_title,
       SUM(review_comment_message IS NULL) AS missing_message,
       SUM(review_comment_title IS NULL
           AND review_comment_message IS NULL
          ) AS score_only_reviews
FROM raw_reviews;

-- Comment missingness & Score relationship:
SELECT review_score,
       COUNT(*) AS total_reviews,
       SUM(review_comment_message IS NOT NULL) AS reviews_with_message,
       ROUND(100 * SUM(review_comment_message IS NOT NULL) / COUNT(*), 2) AS pct_with_message
FROM raw_reviews
GROUP BY review_score
ORDER BY review_score ASC;

-- -- FINDING:
-- The percentage of reviews with a written message increases as review scores decrease from 5 to 1
-- -> Lower-scoring customers are more likely to provide written feedback
--
-- ANALYTICAL IMPLICATION:
-- Review text disproportionately reflects lower-satisfaction experiences
-- Any future text analysis should account for this selection pattern rather than generalizing written comments to the full reviewer population

-- English translations:
SELECT COUNT(DISTINCT p.product_category_name) AS product_categories,
       COUNT(DISTINCT t.product_category_name) AS translated_categories,
       (COUNT(DISTINCT p.product_category_name) - COUNT(DISTINCT t.product_category_name)) AS untranslated_categories
FROM raw_products p
LEFT JOIN raw_product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL;

SELECT DISTINCT p.product_category_name
FROM raw_products p
LEFT JOIN raw_product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- FINDING:
-- Only two non-null product categories lack a corresponding English translation: pc_gamer and portateis_cozinha_e_preparadores_de_alimentos

-- Geographic coverage of customer ZIP prefixes:
SELECT COUNT(DISTINCT c.customer_zip_code_prefix) AS customer_zip_prefixes,
       COUNT(DISTINCT CASE
             WHEN g.geolocation_zip_code_prefix IS NOT NULL
             THEN c.customer_zip_code_prefix
         END) AS matched_zip_prefixes,
       COUNT(DISTINCT CASE
             WHEN g.geolocation_zip_code_prefix IS NULL
             THEN c.customer_zip_code_prefix
         END) AS unmatched_zip_prefixes
FROM raw_customers c
LEFT JOIN (SELECT DISTINCT geolocation_zip_code_prefix
           FROM raw_geolocation) g
       ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;

SELECT COUNT(DISTINCT s.seller_zip_code_prefix) AS seller_zip_prefixes,
       COUNT(DISTINCT CASE
             WHEN g.geolocation_zip_code_prefix IS NOT NULL
             THEN s.seller_zip_code_prefix
         END) AS matched_zip_prefixes,
       COUNT(DISTINCT CASE
             WHEN g.geolocation_zip_code_prefix IS NULL
             THEN s.seller_zip_code_prefix
         END) AS unmatched_zip_prefixes
FROM raw_sellers s
LEFT JOIN (SELECT DISTINCT geolocation_zip_code_prefix
           FROM raw_geolocation) g
       ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix;

-- FINDING:
-- Geolocation coverage is high but incomplete: 157/14.994 (1.05%) absent customer ZIP prefixes, 7/2,246 absent seller ZIP prefixes (0.31%)
-- Geographic analyses requiring coordinates will exclude or require separate handling for entities associated with unmatched ZIP prefixes
-- Before assessing the material impact, quantify how many customers, sellers, orders, and sales are associated with these unmatched prefixes

-- ================================================================================================================================================================
-- 3. CATEGORICAL DOMAINS & VALIDITY
-- Purpose: Identify the values present in key categorical fields, validate their domains, and flag categories requiring special treatment in downstream analysis
-- ================================================================================================================================================================

-- Order status:
SELECT order_status,
       COUNT(*) AS order_count,
       ROUND((COUNT(*) / SUM(COUNT(*)) OVER ()) * 100, 2) AS pct_orders
FROM raw_orders
GROUP BY order_status
ORDER BY order_count DESC;

-- FINDING:
-- Order status is heavily concentrated in delivered orders (97.02%).

-- MODELING NOTE:
-- Fulfillment and delivery metrics should generally be based on completed/delivered orders, while order-volume or cancellation analyses may require retaining other statuses
-- A consistent definition of completed versus non-completed orders should be established in the analytical model

-- Payment methods:
SELECT payment_type,
       COUNT(*) AS payment_records,
       ROUND(((COUNT(*) / SUM(COUNT(*)) OVER ()) * 100), 2) AS pct_payment_records
FROM raw_payments
GROUP BY payment_type
ORDER BY payment_records DESC;

SELECT *
FROM raw_payments
WHERE payment_type = 'not_defined';

-- FINDING:
-- Credit cards dominate payment records (73.92%), followed by boleto (19.04%). Voucher and debit-card payments are relatively uncommon.
-- Three records with payment_type = 'not_defined' have zero-value payment records with a single payment sequence and one installment
-- -> suggesting they do not represent ordinary paid transactions
--
-- FOLLOW-UP:
-- Investigate the corresponding orders and determine how not-defined payments should be treated when defining financial KPIs

SELECT MIN(payment_installments) AS min_installments,
       MAX(payment_installments) AS max_installments,
       COUNT(DISTINCT payment_installments) AS distinct_values
FROM raw_payments;

SELECT payment_installments,
       COUNT(*) AS payment_records
FROM raw_payments
GROUP BY payment_installments
ORDER BY payment_installments;

SELECT *
FROM raw_payments
WHERE payment_installments = 0;

-- DATA QUALITY NOTE:
-- Two credit-card payment records report 0 installments despite having positive payment values 
-- Both are payment sequence 2, indicating they belong to orders with multiple payment records
-- The meaning of 0 installments is not established by the source documentation
-- These values should not be automatically interpreted as either invalid or equivalent to a single installment

-- Review-score:
SELECT review_score,
       COUNT(*) AS review_count,
       ROUND(((COUNT(*) / SUM(COUNT(*)) OVER ()) * 100), 2) AS pct_reviews
FROM raw_reviews
GROUP BY review_score
ORDER BY review_score;

-- VALIDITY NOTE:
-- Review scores fall entirely within the expected 1–5 scale
-- Satisfaction patterns will be explored separately

-- State-code customers:
SELECT customer_state,
       COUNT(*) AS customer_records
FROM raw_customers
GROUP BY customer_state
ORDER BY customer_records DESC;

-- State-code sellers:
SELECT seller_state,
       COUNT(*) AS seller_records
FROM raw_sellers
GROUP BY seller_state
ORDER BY seller_records DESC;

-- VALIDITY NOTE:
-- Customer and seller state fields contain consistent two-letter state codes, no apparent malformed or unexpected values

-- Category:
SELECT COUNT(DISTINCT product_category_name) AS distinct_categories
FROM raw_products
WHERE product_category_name IS NOT NULL;

SELECT product_category_name,
       COUNT(*) AS product_count
FROM raw_products
WHERE product_category_name IS NOT NULL
GROUP BY product_category_name
ORDER BY product_count ASC;

-- VALIDITY NOTE:
-- Category sizes vary substantially, including several sparsely represented categories

-- ============================================================
-- SECTION 4: REFERENTIAL INTEGRITY
-- ============================================================

-- Orders without matching customers:
SELECT COUNT(*) AS orphan_orders
FROM raw_orders o
LEFT JOIN raw_customers c
     ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items without matching orders:
SELECT COUNT(*) AS orphan_order_items
FROM raw_order_items oi
LEFT JOIN raw_orders o
     ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items without matching products:
SELECT COUNT(*) AS orphan_order_items_products
FROM raw_order_items oi
LEFT JOIN raw_products p
     ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- Order items without matching sellers:
SELECT COUNT(*) AS orphan_order_items_sellers
FROM raw_order_items oi
LEFT JOIN raw_sellers s
     ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Payments without matching orders:
SELECT COUNT(*) AS orphan_payments
FROM raw_payments p
LEFT JOIN raw_orders o
     ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Reviews without matching orders:
SELECT COUNT(*) AS orphan_reviews
FROM raw_reviews r
LEFT JOIN raw_orders o
     ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- FINDING:
-- No orphan records were found across the core transactional relationships tested (orders-customers, order_items-orders/products/sellers, payments-orders, and reviews-orders).
--
-- MODELING IMPLICATION:
-- Core analytical joins can be performed without record loss caused by unmatched foreign-key values

-- ============================================================
-- SECTION 5: TEMPORAL COVERAGE
-- ============================================================

-- Purchase date coverage:
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order,
       COUNT(*) AS order_count
FROM raw_orders;

-- Monthly order coverage:
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
       COUNT(*) AS order_count
FROM raw_orders
GROUP BY 1
ORDER BY order_month;


-- Delivery-date coverage:
SELECT MIN(order_delivered_customer_date) AS first_delivery,
       MAX(order_delivered_customer_date) AS last_delivery,
       COUNT(*) AS delivered_orders_with_delivery_date
FROM raw_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- FINDING:
-- Order purchase timestamps span from 2016-09-04 to 2018-10-17
-- Activity is extremely sparse in late 2016, including no orders in November 2016, before becoming continuous from January 2017 through August 2018
-- September and October 2018's activity are sparse
--
-- MODELING IMPLICATION:
-- January 2017 through August 2018 provides the most appropriate continuous full-month window for month-over-month trend analysis












