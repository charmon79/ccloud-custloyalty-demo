# ccloud-custloyalty-demo
Confluent Cloud demo loosely based on "Build Customer Loyalty Schemes" recipe from Confluent Solutions Hub.

Demonstrates and end-to-end realtime data pipeline from MongoDB Atlas to Google BigQuery which does the following:

* Enriches orders data with information about products & customers associated with the order
* Sends the enriched orders data to BigQuery
* Computes in real-time a loyalty reward scheme in which a customer earns a free beverage after every 5 purchases. (An example of how real-time processing can help enhance the customer experience & drive customer engagement.)

## Repo Structure
The `infra` directory contains Terraform code to create Confluent Cloud resources:
- A Confluent Cloud environment
- A Basic tier Kafka cluster deployed in GCP
- Stream Governance Essentials (Schema Registry) package enabled in the Environment
- A Service Account with role bindings to grant it (VERY liberal) permissions on Kafka & Schema Registry.
- A ksqlDB cluster
- A MongoDB Atlas Source connector
- A BigQuery Sink connector
  - Note: the BigQuery Sink connector resource (`confluent_connector.bigquery_sink`) is commented out to start. This is because it depends upon the existence of a Kafka topic which won't exist until the `ksql_queries.sql` script has been run in ksqlDB.

The `src` directory contains:
- Sample data to insert into MongoDB, along with example scripts demonstrating how to insert the data using `mongoimport`.
  - `run_example.sh` should be used first to initially populate the required collections.
  - `add_orders_example.sh` should be used later, after all of the other resources have been created, to demonstrate new data being processed in real time as it is created.
- `ksql_queries.sql` has all of the KSQL necessary to create the stream processing topology to do two things:
  - Create an enriched view of orders data that includes information about the customer, the item ordered, and the total (price * quantity) of each item on an order.
  - Create a view of customers' progress toward meeting the criteria for a hypothetical promotional offer in which every 5 purchases earns a free drink.
  