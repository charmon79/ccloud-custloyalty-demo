###
# You will need a cloud API key to authenticate Terraform to Confluent Cloud
#
# 1. Create a Cloud API key as documented here: https://docs.confluent.io/cloud/current/access-management/authenticate/api-keys/api-keys.html#cloud-cloud-api-keys
# 2. Create the file ~/.confluent-cloud-tf-auth which will be sourced to export the necessary environment variables:
#     export CONFLUENT_CLOUD_API_KEY="your API key"
#     export CONFLUENT_CLOUD_API_SECRET="your API secret"
#
#    This method avoids the risk of accidentally committing the API key & secret to this repo.
###

source ~/.confluent-cloud-tf-auth
