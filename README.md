# ccloud-custloyalty-demo
Confluent Cloud demo loosely based on "Build Customer Loyalty Schemes" recipe from Confluent Solutions Hub.

Demonstrates and end-to-end realtime data pipeline from MongoDB Atlas to Google BigQuery which does the following:

* Enriches orders data with information about products & customers associated with the order
* Sends the enriched orders data to BigQuery
* Computes in real-time a loyalty reward scheme in which a customer earns a free beverage after every 5 purchases. (An example of how real-time processing can help enhance the customer experience & drive customer engagement.)
