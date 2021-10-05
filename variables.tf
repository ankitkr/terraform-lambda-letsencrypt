variable "region" {}

variable "account_id" {}

variable "s3_bucket_name" {}

variable "s3_prefix" {}

variable "route53_zone_id" {}

variable "sns_topic_name" {
  default = ""
}

variable "notification_sns_arn" {
  default = ""
}

variable "certificate_domains" {}

variable "contact_email" {}

variable "lambda_name" {}
