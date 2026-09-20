USE olist_analytics;

CREATE TABLE IF NOT EXISTS raw_customers (
  customer_id CHAR(32) PRIMARY KEY,
  customer_unique_id CHAR(32) NOT NULL,
  customer_zip_code_prefix INT NOT NULL,
  customer_city VARCHAR(100) NOT NULL,
  customer_state CHAR(2) NOT NULL
);

CREATE TABLE IF NOT EXISTS raw_orders (
  order_id CHAR(32) PRIMARY KEY,
  customer_id CHAR(32) UNIQUE NOT NULL,
  order_status VARCHAR(32) NOT NULL,
  order_purchase_timestamp DATETIME NOT NULL,
  order_approved_at DATETIME,
  order_delivered_carrier_date DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS raw_order_items (
  order_id CHAR(32) NOT NULL,
  order_item_id INT NOT NULL,
  product_id CHAR(32) NOT NULL,
  seller_id CHAR(32) NOT NULL,
  shipping_limit_date DATETIME NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  freight_value DECIMAL(10,2) NOT NULL,
  PRIMARY KEY(order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS raw_products (
  product_id CHAR(32) PRIMARY KEY,
  product_category_name VARCHAR(100),
  product_name_lenght INT,
  product_description_lenght INT,
  product_photos_qty INT,
  product_weight_g INT,
  product_length_cm INT,
  product_height_cm INT,
  product_width_cm INT
);

CREATE TABLE IF NOT EXISTS raw_sellers (
  seller_id CHAR(32) PRIMARY KEY,
  seller_zip_code_prefix INT NOT NULL,
  seller_city VARCHAR(100) NOT NULL,
  seller_state CHAR(2) NOT NULL
);

CREATE TABLE IF NOT EXISTS raw_payments (
    order_id CHAR(32) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10,2) NOT NULL,
    PRIMARY KEY(order_id, payment_sequential)
);

CREATE TABLE IF NOT EXISTS raw_reviews (
  review_id CHAR(32) NOT NULL,
  order_id CHAR(32) NOT NULL,
  review_score INT NOT NULL,
  review_comment_title VARCHAR(100),
  review_comment_message TEXT,
  review_creation_date DATETIME NOT NULL,
  review_answer_timestamp DATETIME NOT NULL,
  PRIMARY KEY (review_id, order_id)
);

CREATE TABLE IF NOT EXISTS raw_geolocation (
  geolocation_zip_code_prefix INT NOT NULL,
  geolocation_lat DOUBLE NOT NULL,
  geolocation_lng DOUBLE NOT NULL,
  geolocation_city VARCHAR(100) NOT NULL,
  geolocation_state CHAR(2) NOT NULL
);

CREATE TABLE IF NOT EXISTS raw_product_category_name_translation (
  product_category_name VARCHAR(100) PRIMARY KEY,
  product_category_name_english VARCHAR(100) NOT NULL
);




