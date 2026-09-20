import csv
import getpass
import mysql.connector

CSV_PATH = (
    "/Users/giahan/Documents/GitHub/olist-analysis/data/raw/"
    "Brazilian E-Commerce Public Dataset by Olist/"
    "olist_order_reviews_dataset.csv"
)

# Ask for the MySQL password at runtime instead of storing it in the file.
password = getpass.getpass("MySQL root password: ")

connection = mysql.connector.connect(
    host="localhost",
    user="root",
    password=password,
    database="olist_analytics"
)

cursor = connection.cursor()

# Start with an empty reviews table.
cursor.execute("TRUNCATE TABLE raw_reviews")

insert_sql = """
INSERT INTO raw_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
VALUES (%s, %s, %s, %s, %s, %s, %s)
"""

row_count = 0

with open(CSV_PATH, "r", encoding="utf-8", newline="") as file:
    reader = csv.DictReader(file)

    for row in reader:
        values = (
            row["review_id"],
            row["order_id"],
            int(row["review_score"]),
            row["review_comment_title"] or None,
            row["review_comment_message"] or None,
            row["review_creation_date"],
            row["review_answer_timestamp"]
        )

        cursor.execute(insert_sql, values)
        row_count += 1

connection.commit()

cursor.close()
connection.close()

print(f"Imported {row_count:,} review records.")