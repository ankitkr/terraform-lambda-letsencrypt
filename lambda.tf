module "lambda_layer_packages" {
  source = "git::git@github.com:terraform-aws-modules/terraform-aws-lambda.git?ref=v2.10.0"

  create_layer = true

  layer_name               = "${local.service}-package-layer"
  description              = "Lambda layer for packages"
  compatible_runtimes      = ["python3.6"]
  compatible_architectures = ["arm64"]

  source_path = "${path.module}/package/"
  store_on_s3 = false
}