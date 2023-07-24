locals {
  cluster_name = "demo_cluster"
  description  = "Created via Terraform based on CC Quick Start guide"
  cloud        = "GCP"
  region       = "us-central1"
  sr_region    = "us-central1"
}

variable "confluent_cloud_api_key" {
  type = string
}

variable "confluent_cloud_api_secret" {
  type = string
}

variable "env_name" {
  type    = string
  default = "mongo_bq_pipeline_demo"
}

variable "mongodb_config" {
  type = object({
    host     = string
    database = string
    user     = string
    password = string
  })
}

variable "bigquery_config" {
  type = object({
    project  = string
    datasets = string
    keyfile  = string
  })
}