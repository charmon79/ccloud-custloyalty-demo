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
    KAFKA_TOPIC = 'orders_enriched',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS = 1
)
AS SELECT
    O.ORDER_ID,
    AS_VALUE(U.USER_ID) AS USER_ID,
    U.NAME AS USER_NAME,
    U.EMAIL,
    U.GENDER,
    O.ORDER_TIMESTAMP,
    P.ITEM_ID AS ITEM_ID_KEY, -- 
    AS_VALUE(P.ITEM_ID) AS ITEM_ID,
    O.QTY,
    P.NAME AS ITEM_NAME,
    P.CATEGORY,
    P.PRICE AS UNIT_PRICE,
    (P.PRICE * O.QTY) AS TOTAL_PRICE
FROM ORDERS_EXPLODED O
INNER JOIN USERS U ON O.USER_ID = U.USER_ID
INNER JOIN PRODUCTS P ON O.ITEM_ID = P.ITEM_ID
EMIT CHANGES
;

/*
    Let's imagine that after every 5 orders, their next beverage is free.

    We can automatically emit an event after 5 orders to indicate
    that the customer is entitled to a free beverage on their next visit.
    Since this will emit an event to the 'free_drink_rewards' topic,
    that topic can be consumed to notify customers & issue reward coupons
    instantly once they qualify.
    
    By using a Table, we can also refer to this
    as a materialized view of where each customer currently stands toward
    their next free drink. Applications could look up a customer's reward
    status using the ksqlDB API, or we could sink this to a database
    for applications to perform lookups against.
*/

CREATE TABLE FREE_DRINK_REWARDS
WITH (
    KAFKA_TOPIC = 'free_drink_rewards',
    KEY_FORMAT = 'KAFKA',
    VALUE_FORMAT = 'AVRO',
    PARTITIONS = 1
)
AS SELECT
  USER_ID,
  COUNT(*) AS TOTAL_ORDERS,
  (COUNT(*) % 6) AS CURRENT_SEQUENCE,
  (COUNT(*) % 6) = 5 AS FREE_DRINK_EARNED
FROM ORDERS_RAW
GROUP BY USER_ID
EMIT CHANGES
;
