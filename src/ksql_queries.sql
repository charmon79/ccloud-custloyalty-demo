/*
    Step 1: Create streams over the raw source topics.
            Because the MongoDB Source Connector was configured to serialize the
            message value as Avro, we can take advantage of Schema Inference and avoid
            explicltly specifying all of the fields in each stream here.
*/
CREATE SOURCE STREAM USERS_RAW
WITH (
  KAFKA_TOPIC = 'mongo.coffeeshop.users',
  KEY_FORMAT = 'KAFKA',
  VALUE_FORMAT = 'AVRO'
);
  
CREATE SOURCE STREAM PRODUCTS_RAW
WITH (
  KAFKA_TOPIC = 'mongo.coffeeshop.products',
  KEY_FORMAT = 'KAFKA',
  VALUE_FORMAT = 'AVRO'
);

CREATE SOURCE STREAM ORDERS_RAW
WITH (
  KAFKA_TOPIC = 'mongo.coffeeshop.orders',
  KEY_FORMAT = 'KAFKA',
  VALUE_FORMAT = 'AVRO'
);

/*
    Step 2: We need to use Users and Products as lookup tables to enrich events
            from the Orders stream. Therefore, we need to create a Table based on each.
            In doing so, we also need to change the key of each record to the appropriate
            business key from the collection (rather than the MongoDB oid as it is in the
            raw source streams).
*/
CREATE TABLE USERS
WITH (
    KAFKA_TOPIC = 'ksql.coffeeshop.users',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS = 1
)
AS SELECT
    USER_ID,
    LATEST_BY_OFFSET(`NAME`) AS `NAME`,
    LATEST_BY_OFFSET(EMAIL) AS EMAIL,
    LATEST_BY_OFFSET(GENDER) AS GENDER
FROM USERS_RAW
GROUP BY USER_ID
EMIT CHANGES
;

CREATE TABLE PRODUCTS
WITH (
    KAFKA_TOPIC = 'ksql.coffeeshop.products',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS = 1
)
AS SELECT
    ITEM_ID,
    LATEST_BY_OFFSET(CATEGORY) AS CATEGORY,
    LATEST_BY_OFFSET(`NAME`) AS `NAME`,
    LATEST_BY_OFFSET(NUTRITION) AS NUTRITION,
    LATEST_BY_OFFSET(PRICE) AS PRICE
FROM PRODUCTS_RAW
GROUP BY ITEM_ID
EMIT CHANGES
;

/*
    The raw Orders document from MongoDB contains an array of IDs & quantities of
    the products which were purchased on that order. We need to explode out that
    array and yield 1 record per item ordered so that we can join this stream
    back to the Products table to compute price.
*/
CREATE STREAM ORDERS_EXPLODED
WITH (
  KAFKA_TOPIC = 'ksql.coffeeshop.orders_exploded',
  KEY_FORMAT = 'KAFKA',
  VALUE_FORMAT = 'AVRO',
  PARTITIONS = 1
)
AS SELECT
  ORDER_ID,
  USER_ID,
  ORDER_TIMESTAMP,
  EXPLODE(ITEMS)->ITEM_ID,
  EXPLODE(ITEMS)->QTY
FROM ORDERS_RAW
EMIT CHANGES
;

/*
    Create enriched Orders stream, denormalized to include details
    about the User and the Products 
*/
CREATE STREAM ORDERS_ENRICHED
WITH (
    KAFKA_TOPIC = 'ksql.coffeeshop.orders_enriched',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS = 1
)
AS SELECT
    O.ORDER_ID,
    O.USER_ID USER_ID,
    U.NAME USER_NAME,
    U.EMAIL,
    U.GENDER,
    O.ORDER_TIMESTAMP,
    O.ITEM_ID ITEM_ID,
    O.QTY,
    P.NAME ITEM_NAME,
    P.CATEGORY,
    P.PRICE UNIT_PRICE,
    (P.PRICE * O.QTY) TOTAL_PRICE
FROM ORDERS_EXPLODED O
INNER JOIN USERS U ON O.USER_ID = U.USER_ID
INNER JOIN PRODUCTS P ON O.ITEM_ID = P.ITEM_ID
EMIT CHANGES
;

/*
    Let's imagine that after every 5 beverages a customer orders, their next
    beverage is free.

    We can automatically emit an event after 5 beverage purchases to indicate
    that the next one is free. By using a Table, we can also refer to this
    as a materialized view of where each customer currently stands toward
    their next free drink.
*/

CREATE TABLE BEVERAGE_LOYALTY_STATUS
WITH (
    KAFKA_TOPIC = 'beverage_loyalty_status',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS = 1
)
AS SELECT
  USER_ID,
  COUNT(*) AS TOTAL,
  (COUNT(*) % 6) AS CURRENT_SEQUENCE,
  (COUNT(*) % 6) = 5 AS NEXT_ONE_FREE
FROM ORDERS_ENRICHED
WHERE CATEGORY = 'Beverage'
GROUP BY USER_ID
EMIT CHANGES;
