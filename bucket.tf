module "s3_bucket" {
  source = "git::git@github.com:vy-labs/vastu-elements.git//aws/s3?ref=development"

  bucket_name                   = var.s3_bucket_name
  acl                           = "private"
  force_destroy                 = true
  versioning_enabled            = true
  sse_algorithm                 = "aws:kms"
  lifecycle_rules               = [{
    enabled = true
    prefix  = ""
    tags    = {}

    enable_glacier_transition            = false
    enable_deeparchive_transition        = false
    enable_standard_ia_transition        = false
    enable_current_object_expiration     = false
    enable_noncurrent_version_expiration = true

    abort_incomplete_multipart_upload_days         = 30
    noncurrent_version_glacier_transition_days     = 60
    noncurrent_version_deeparchive_transition_days = 60
    noncurrent_version_expiration_days             = 90

    standard_transition_days    = 90
    glacier_transition_days     = 180
    deeparchive_transition_days = 180
    expiration_days             = 365
  }, {
    enabled = true
    prefix  = "archive/"
    tags    = {}

    enable_glacier_transition            = false
    enable_deeparchive_transition        = false
    enable_standard_ia_transition        = false
    enable_current_object_expiration     = true
    enable_noncurrent_version_expiration = true

    abort_incomplete_multipart_upload_days         = 30
    noncurrent_version_glacier_transition_days     = 60
    noncurrent_version_deeparchive_transition_days = 60
    noncurrent_version_expiration_days             = 90

    standard_transition_days    = 60
    glacier_transition_days     = 180
    deeparchive_transition_days = 180
    expiration_days             = 180
  }]
  block_public_acls             = true
  block_public_policy           = true
  ignore_public_acls            = true
  restrict_public_buckets       = true
}