locals {
  service              = "certbot-lambda"
  lambda_function_name = join("-", split(".", var.lambda_name))
  log_group_name       = "/aws/lambda/${local.lambda_function_name}"
}
