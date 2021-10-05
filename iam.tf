locals {
  iam_policy_file = format("%s/%s/%s", abspath(path.module), "config", "iam-policies.yaml")

  iam_policies = yamldecode(data.template_file.policy.rendered)
  iam_policy_map = {
    for policy in local.iam_policies :
    policy.name => policy.policy
  }
}

data "template_file" "policy" {
  template = file(local.iam_policy_file)

  vars = {
    aws_region          = var.region
    aws_account_id      = var.account_id
    aws_s3_bucket       = var.s3_bucket_name
    aws_route53_zone_id = var.route53_zone_id
    log_group_name      = local.log_group_name
    sns_topic_name      = var.sns_topic_name
  }
}

module "iam_role" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/iam-role?ref=development"

  iam_role_name                     = "certbot-lambda"
  iam_role_path                     = "/lambdas/"
  iam_role_description              = "Permit lamda to communicate with various AWS resources"
  assume_role_principal_type        = "Service"
  assume_role_principal_identifiers = ["lambda.amazonaws.com"]
  iam_role_tags = {
    "Service" = local.service,
    "Target"  = local.lambda_function_name
  }
}

module "iam_policy" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/iam-role-policy?ref=development"

  for_each = local.iam_policy_map

  iam_role              = module.iam_role.iam_role.id
  iam_policy_name       = each.key
  iam_policy_statements = each.value
}
