#module "lambda_layer_packages" {
#  source = "git::git@github.com:terraform-aws-modules/terraform-aws-lambda.git?ref=v2.20.0"
#
#  create_layer = true
#
#  layer_name               = "${local.service}-package-layer"
#  description              = "Lambda layer for packages"
#  compatible_runtimes      = ["python3.6"]
#  compatible_architectures = ["arm64"]
#
#  source_path = "${path.module}/package/"
#  store_on_s3 = false
#}

module "certbot_lambda" {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-lambda.git?ref=v2.20.0"


  function_name = local.lambda_function_name
  lambda_role   = module.iam_role.iam_role.arn
  description   = format("CertBot Lambda that creates and renews certificates for %s", var.certificate_domains)
  handler       = "main.lambda_handler"
  runtime       = "python3.6"
  timeout       = 300
  architectures = ["arm64"]
  source_path = [
    {
      path             = "${path.module}/src/"
      pip_requirements = "${path.module}/src/requirements.txt"
    }
  ]
  #  source_path   = "${path.module}/src/"
  #  layers = [
  #    module.lambda_layer_packages.lambda_layer_arn
  #  ]

  create_role                               = false
  store_on_s3                               = false
  use_existing_cloudwatch_log_group         = true
  create_current_version_allowed_triggers   = false
  create_unqualified_alias_allowed_triggers = false

  environment_variables = {
    EMAIL     = var.contact_email
    DOMAINS   = var.certificate_domains
    S3_BUCKET = module.s3_bucket.bucket.id
    S3_PREFIX = var.s3_prefix
    SNS_ARN   = var.notification_sns_arn
  }

  tags = {
    "Service" = local.service,
    "Target"  = local.lambda_function_name
  }

  depends_on = [
    module.s3_bucket,
    module.cloudwatch_log_group
  ]
}
