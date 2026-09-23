USE olist_analytics;

-- Order item metrics:
CREATE OR REPLACE VIEW view_order_item_metrics AS
SELECT order_id,
       COUNT(*) AS item_count,
       COUNT(DISTINCT product_id) AS distinct_product_count,
       COUNT(DISTINCT seller_id) AS seller_count,
       SUM(price) AS merchandise_value,
       SUM(freight_value) AS freight_value,
       SUM(price + freight_value) AS item_total_value
FROM raw_order_items
GROUP BY order_id;

-- Payment metrics:
CREATE OR REPLACE VIEW view_order_payment_metrics AS
SELECT order_id,
       COUNT(*) AS payment_record_count,
       SUM(payment_value) AS payment_value
FROM raw_payments
GROUP BY order_id;

-- Review metrics:
CREATE OR REPLACE VIEW view_order_review_metrics AS
SELECT order_id,
       COUNT(*) AS review_count,
       AVG(review_score) AS avg_review_score
FROM raw_reviews
GROUP BY order_id;

-- ============================================================
-- ORDER-LEVEL ANALYTICAL VIEW
-- Grain: one row per order_id
-- ============================================================
CREATE OR REPLACE VIEW view_order_analysis AS
SELECT
    -- Order and customer identifiers:
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    -- Customer geography:
    c.customer_city,
    c.customer_state,
    -- Order status and timestamps:
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    -- Order item metrics:
    i.item_count,
    i.distinct_product_count,
    i.seller_count,
    i.merchandise_value,
    i.freight_value,
    i.item_total_value,
    -- Payment metrics:
    p.payment_record_count,
    p.payment_value,
    -- Review metrics:
    r.review_count,
    r.avg_review_score,
    -- Fulfillment metrics:
    TIMESTAMPDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_variance_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL
            THEN NULL
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 1
        ELSE 0
    END AS on_time_flag
FROM raw_orders o
LEFT JOIN raw_customers c
       ON o.customer_id = c.customer_id
LEFT JOIN view_order_item_metrics i
       ON o.order_id = i.order_id
LEFT JOIN view_order_payment_metrics p
    ON o.order_id = p.order_id
LEFT JOIN view_order_review_metrics r
    ON o.order_id = r.order_id;


