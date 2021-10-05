module "cloudwatch_event" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/cloudwatch/event?ref=development"

  rule_name           = "${local.service}-timer-${local.lambda_function_name}"
  rule_description    = "Create a timer that runs every day at 1 AM(UTC)"
  schedule_expression = "cron(0 1 * * ? *)"
  target_arn          = module.certbot_lambda.function_arn
  rule_tags = {
    "Service" = local.service
    "Target"  = local.lambda_function_name
  }
}

module "cloudwatch_lambda_permission" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/lambda/permission?ref=development"

  name          = "${local.service}-${local.lambda_function_name}-invoke-permission"
  action        = "lambda:InvokeFunction"
  function_name = module.certbot_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.cloudwatch_event.event_rule.arn
}
