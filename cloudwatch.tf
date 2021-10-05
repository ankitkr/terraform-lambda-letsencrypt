module "cloudwatch_event" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/cloudwatch/event?ref=development"

  rule_name           = "${local.service}-timer-${local.lambda_function_name}"
  rule_description    = "Create a timer that runs every day at 1 AM(UTC)"
  schedule_expression = "cron(0 1 * * ? *)"
  target_arn          = module.certbot_lambda.function_arn
  rule_tags = {
    "Service" = local.service,
    "Target"  = local.lambda_function_name
  }
}

module "cloudwatch_lambda_permission" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/lambda/permission?ref=development"

  function_name = module.certbot_lambda.function_name

  name       = "${local.service}-${local.lambda_function_name}-cloudwatch-events"
  action     = "lambda:InvokeFunction"
  principal  = "events.amazonaws.com"
  source_arn = module.cloudwatch_event.event_rule.arn
}

module "cloudwatch_log_group" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/cloudwatch/log-group?ref=development"

  name              = local.log_group_name
  retention_in_days = 7
  tags = {
    "Service" = local.service,
    "Target"  = local.lambda_function_name
  }
}
