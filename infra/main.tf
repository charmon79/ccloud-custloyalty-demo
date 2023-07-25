########################################################################################################
# Generate a random ID so we can avoid this environment colliding with any others you may have created.
########################################################################################################
resource "random_id" "env_id" {
  byte_length = 4
}

########################################################################################################
# Create an Environment
########################################################################################################
resource "confluent_environment" "env" {
  display_name = "${var.env_name}_${random_id.env_id.hex}"
}

########################################################################################################
# Create a Kafka cluster
########################################################################################################
resource "confluent_kafka_cluster" "kafka" {
  display_name = local.cluster_name
  availability = "SINGLE_ZONE"
  cloud        = local.cloud
  region       = local.region
  basic {}

  environment {
    id = confluent_environment.env.id
  }
}

########################################################################################################
# Enable the Stream Governance (a.k.a. Schema Registry) Essentials package on the environment
########################################################################################################
data "confluent_schema_registry_region" "sr_region" {
  cloud   = local.cloud
  region  = local.sr_region
  package = "ESSENTIALS"
}
resource "confluent_schema_registry_cluster" "sr" {
  package = data.confluent_schema_registry_region.sr_region.package
  environment {
    id = confluent_environment.env.id
  }
  region {
    id = data.confluent_schema_registry_region.sr_region.id
  }
}

########################################################################################################
# Create a service account (resources we create later will need to use this for authorization)
########################################################################################################
resource "confluent_service_account" "sa-demo" {
  display_name = "sa-demo-${random_id.env_id.hex}"
  description  = "Service account for Connect and ksqlDB"
}

########################################################################################################
# Create role bindings to grant the service account the permissions it will need
########################################################################################################
resource "confluent_role_binding" "sa-demo-kafka-admin" {
  principal   = "User:${confluent_service_account.sa-demo.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.kafka.rbac_crn
}

resource "confluent_role_binding" "sa-demo-sr-admin" {
  principal   = "User:${confluent_service_account.sa-demo.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${confluent_schema_registry_cluster.sr.resource_name}/subject=*"
}

########################################################################################################
# Create a ksqlDB cluster
########################################################################################################
resource "confluent_ksql_cluster" "ksqldb-app1" {
  display_name = "ksqldb-app1"
  csu          = 1
  kafka_cluster {
    id = confluent_kafka_cluster.kafka.id
  }
  credential_identity {
    id = confluent_service_account.sa-demo.id
  }
  environment {
    id = confluent_environment.env.id
  }
  depends_on = [
    confluent_role_binding.sa-demo-kafka-admin,
    confluent_role_binding.sa-demo-sr-admin,
    confluent_schema_registry_cluster.sr
  ]
}

########################################################################################################
# Create the MongoDB Atlas Source Connector
########################################################################################################
resource "confluent_connector" "mongo_source" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.kafka.id
  }

  config_sensitive = {
    "connection.password" = var.mongodb_config.password
  }

  config_nonsensitive = {
    "name"                                           = "src.mongo.coffeeshop"
    "connector.class"                                = "MongoDbAtlasSource"
    "kafka.auth.mode"                                = "SERVICE_ACCOUNT"
    "kafka.service.account.id"                       = confluent_service_account.sa-demo.id
    "connection.host"                                = var.mongodb_config.host
    "connection.database"                            = var.mongodb_config.database
    "connection.user"                                = var.mongodb_config.user
    "heartbeat.interval.ms"                          = 60000
    "json.output.decimal.format"                     = "BASE64"
    "mongo.errors.tolerance"                         = "ALL"
    "mongo.errors.deadletterqueue.topic.name"        = "mongo.source.errors.dlq"
    "output.json.format"                             = "ExtendedJson"
    "output.data.format"                             = "AVRO"
    "poll.await.time.ms"                             = 1000
    "publish.full.document.only"                     = true
    "publish.full.document.only.tombstone.on.delete" = true
    "startup.mode"                                   = "copy_existing"
    "topic.prefix"                                   = "mongo"
    "tasks.max"                                      = 1
  }

  depends_on = [
    confluent_schema_registry_cluster.sr
  ]
}

########################################################################################################
# Create the Google BigQuery Sink Connector
########################################################################################################
resource "confluent_connector" "bigquery_sink" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.kafka.id
  }

  config_sensitive = {
    "keyfile"                  = var.bigquery_config.keyfile
  }

  config_nonsensitive = {
    "name"                     = "snk.bigquery.coffeeshop"
    "connector.class"          = "BigQuerySink"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.sa-demo.id
    "auto.create.tables"       = true
    "auto.update.schemas"      = true
    "partitioning.type"        = "NONE"
    "project"                  = var.bigquery_config.project
    "datasets"                 = var.bigquery_config.datasets
    "topics"                   = "orders_enriched"
    "input.data.format"        = "AVRO"
    "input.key.format"         = "STRING"
    "tasks.max"                = 1
  }

  depends_on = [
    confluent_schema_registry_cluster.sr
  ]
}
