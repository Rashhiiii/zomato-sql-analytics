# Zomato Order & Customer Analytics (SQL)

An end-to-end SQL project on a Zomato-style relational dataset: inspecting the data, cleaning it, and analysing sales, customers, menu pricing and restaurant ratings.

**Tool:** MySQL (MySQL Workbench) | **Database:** `zomato_db` | **File:** `zomato_database.sql`

## Dataset

Five tables:

| Table | Used for |
|---|---|
| `orders` | 150,281 order records: date, quantity, sales amount, currency, user ID, restaurant ID |
| `restaurant` | 148,515 restaurants with ratings and rating counts |
| `users` | Customer gender and age |
| `food` | 372,561 food items with a veg / non-veg label |
| `menu` | Cuisine labels and menu prices |

Rows in `orders` are treated as **order records**, not confirmed unique orders. INR and USD are always analysed separately.

## Data cleaning

- **Duplicates:** none found across all six columns of `orders`.
- **Missing values:** none in any `orders` column.
- **Currency inconsistency:** the `currency` column showed two versions of INR. Using `HEX()` and `LENGTH()`, I found one version contained a hidden carriage-return character (`0D`). `TRIM()` did not remove it, so I used `REPLACE(currency, CHAR(13), '')`. Result: 150,279 INR records and 2 USD records.
- **Anomalies documented, not altered:** two records with a sales amount of -1.00, and a handful of very large bulk orders (up to 1,510,944.00). There was not enough evidence to decide what the correct values should be.
- **Food table:** two items had no valid veg / non-veg label. One had an empty name, and one had the label stored inside the item name ('Mushroom Corn Biryani,Veg').

## Analysis and findings

| Section | Finding |
|---|---|
| Revenue | INR: 2,444,225 items sold, total revenue 986,564,266.00, average 6,564.88 per record (2017-10 to 2020-06). USD has only 2 records (750.00 total). |
| Monthly trend | INR sales peaked in 2018-01 (42.5M) and trended downward through 2019 and 2020. The first and last months are partial, so they are not real dips. |
| Top restaurants | The top 10 by INR sales each have exactly 1 order record. The ranking reflects single very large orders, not sustained performance. |
| Customers | Customers with a recorded age: 57,218 male and 42,782 female. Average age is about 24.8 (male) and 24.4 (female). |
| Repeat customers | 44,472 of 77,929 customers (57.07%) placed more than one order record. |
| RFM metrics | Recency, frequency and monetary value per customer and currency. The top spenders have only 1 to 4 records, driven by single large orders. |
| Food | 270,775 veg items (about 73%) and 100,784 non-veg (about 27%). |
| Ratings vs sales | 61,430 restaurants have numeric ratings (average 3.89). Medium-rated restaurants had the highest total INR sales (210,873,332.00), followed by high-rated (196,945,118.00). Low-rated restaurants had the highest average per record (7,798.89), and high-rated the lowest (6,288.76). |
| Unmatched IDs | 1,643 order records have no matching restaurant. 1,617 of them use restaurant ID 0, which looks like a placeholder. |

## Limitations

- Only 2 USD records, so no USD analysis is meaningful.
- Most restaurants have about one order, so "order volume" per restaurant barely varies.
- 86,999 restaurants have a non-numeric rating ('--'), so rating analysis covers only the 61,430 with numeric ratings.
- Cuisine labels are combined (for example 'Asian,Desserts'), and some menu prices are 0.00.
- The rating comparison shows association, not causation.
- The low-rated group has about 2,300 records, so a few large orders can move its average.

## SQL skills shown

Joins (inner and left), aggregation and `GROUP BY` / `HAVING`, subqueries, `CASE` expressions, date functions (`DATE_FORMAT`, `DATEDIFF`), regular expressions, and data cleaning with `HEX()`, `TRIM()` and `REPLACE()`.

## How to run

1. Load the five tables into a MySQL database named `zomato_db`.
2. Open `zomato_database.sql` in MySQL Workbench and run it section by section.
3. Section 2.3 contains an `UPDATE` that fixes the currency values. It has already been applied once, so rerunning it changes 0 rows.
