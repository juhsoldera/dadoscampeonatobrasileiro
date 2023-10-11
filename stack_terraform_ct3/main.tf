# ---------------------------------------------------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM Users
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_user" "user" {
  name = "teste_juliana_3"
}

resource "aws_iam_user_policy_attachment" "attach-user-athena" {
  user       = "${aws_iam_user.user.name}"
  policy_arn = var.attach_policy_arn_athena
}

resource "aws_iam_user_policy_attachment" "attach-user-s3" {
  user       = "${aws_iam_user.user.name}"
  policy_arn = var.attach_policy_arn_s3
}

# ---------------------------------------------------------------------------------------------------------------------
# Lake Formation 
# https://docs.aws.amazon.com/lake-formation/latest/dg/cloudtrail-tut-create-lf-user.html
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_policy" "lake_formation_user_role" {
  name        = "DatalakeUserBasic3"
  description = "lake formation user role"

  policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lakeformation:GetDataAccess",
                "glue:GetTable",
                "glue:GetTables",
                "glue:SearchTables",
                "glue:GetDatabase",
                "glue:GetDatabases",
                "glue:GetPartitions",
                "lakeformation:GetResourceLFTags",
                "lakeformation:ListLFTags",
                "lakeformation:GetLFTag",
                "lakeformation:SearchTablesByLFTags",
                "lakeformation:SearchDatabasesByLFTags"                
           ],
            "Resource": "*"
        }
    ]
}
EOT
}

# ---------------------------------------------------------------------------------------------------------------------
# s3 Buckets
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "raw" {
    bucket = "bucket-raw-poc-juliana-4"
}

resource "aws_s3_bucket" "cleaned" {
    bucket = "bucket-cleaned-poc-juliana-4"   
}

resource "aws_s3_bucket" "processed" {
    bucket = "bucket-processed-poc-juliana-4"   
}

resource "aws_s3_bucket" "application" {
    bucket = "bucket-application-poc-juliana-4"   
}

resource "aws_s3_bucket" "athena_query_results" {
    bucket = "bucket-athena-query-results-poc-juliana-4"   
}

resource "aws_s3_bucket" "jobs" {
    bucket = "bucket-jobs-poc-juliana-4"   
}

resource "aws_s3_bucket" "logs" {
    bucket = "bucket-logs-poc-juliana-4"   
}

# ---------------------------------------------------------------------------------------------------------------------
# s3 Files Upload
# ---------------------------------------------------------------------------------------------------------------------

# resource "aws_s3_object" "cleaned_job" {

#   bucket = aws_s3_bucket.jobs.id
#   key    = "process_data_from_campeonato_brasileiro/raw_data_to_cleaned.py"
#   acl    = "private"  # or can be "public-read"
#   source = "./scripts/pyspark-jobs/raw_data_to_cleaned.py"

# }

# resource "aws_s3_object" "airflow_dags" {

#   bucket = aws_s3_bucket.application.id
#   key    = "dags/process-campeonato-brasileiro-data.py"
#   acl    = "private"  # or can be "public-read"
#   source = "./scripts/airflow/dags/process-campeonato-brasileiro-data.py"

# }

# resource "aws_s3_object" "airflow_requirements" {

#   bucket = aws_s3_bucket.application.id
#   key    = "requirements/requirements.txt"
#   acl    = "private"  # or can be "public-read"
#   source = "./scripts/airflow/requirements/requirements.txt"

# }

# resource "aws_s3_object" "raw_data" {

#   count  = length(var.files_to_upload)
#   bucket = aws_s3_bucket.raw.id
#   key    = "campeonato_brasileiro_dataset-main/${basename(var.files_to_upload[count.index])}"
#   source = var.files_to_upload[count.index]
#   acl    = "private"

# }
# ---------------------------------------------------------------------------------------------------------------------
# MWAA Environment
# https://github.com/aws-ia/terraform-aws-mwaa/tree/main
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_mwaa_environment" "mwaa" {
  name              = var.airflow_name
  airflow_version   = var.airflow_version
  environment_class = var.environment_class
  min_workers       = var.min_workers
  max_workers       = var.max_workers
  kms_key           = var.kms_key

  dag_s3_path                      = var.dag_s3_path
  plugins_s3_object_version        = var.plugins_s3_object_version
  plugins_s3_path                  = var.plugins_s3_path
  requirements_s3_path             = var.requirements_s3_path
  requirements_s3_object_version   = var.requirements_s3_object_version
  startup_script_s3_path           = var.startup_script_s3_path
  startup_script_s3_object_version = var.startup_script_s3_object_version
  schedulers                       = var.schedulers
  execution_role_arn               = local.execution_role_arn
  airflow_configuration_options    = local.airflow_configuration_options

  source_bucket_arn               = local.source_bucket_arn
  webserver_access_mode           = var.webserver_access_mode
  weekly_maintenance_window_start = var.weekly_maintenance_window_start

  tags = var.tags

  network_configuration {
    security_group_ids = local.security_group_ids
    subnet_ids         = var.private_subnet_ids
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = try(var.logging_configuration.dag_processing_logs.enabled, true)
      log_level = try(var.logging_configuration.dag_processing_logs.log_level, "INFO")
    }

    scheduler_logs {
      enabled   = try(var.logging_configuration.scheduler_logs.enabled, true)
      log_level = try(var.logging_configuration.scheduler_logs.log_level, "INFO")
    }

    task_logs {
      enabled   = try(var.logging_configuration.task_logs.enabled, true)
      log_level = try(var.logging_configuration.task_logs.log_level, "INFO")
    }

    webserver_logs {
      enabled   = try(var.logging_configuration.webserver_logs.enabled, true)
      log_level = try(var.logging_configuration.webserver_logs.log_level, "INFO")
    }

    worker_logs {
      enabled   = try(var.logging_configuration.worker_logs.enabled, true)
      log_level = try(var.logging_configuration.worker_logs.log_level, "INFO")
    }
  }

  lifecycle {
    ignore_changes = [
      plugins_s3_object_version,
      requirements_s3_object_version
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM Role
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "mwaa" {
  count = var.create_iam_role ? 1 : 0

  name                  = var.iam_role_name != null ? var.iam_role_name : null
  name_prefix           = var.iam_role_name != null ? null : "mwaa-executor"
  description           = "MWAA IAM Role"
  assume_role_policy    = data.aws_iam_policy_document.mwaa_assume.json
  force_detach_policies = var.force_detach_policies
  path                  = var.iam_role_path
  permissions_boundary  = var.iam_role_permissions_boundary

  tags = var.tags
}

resource "aws_iam_role_policy" "mwaa" {
  count = var.create_iam_role ? 1 : 0

  name_prefix = "mwaa-executor"
  role        = aws_iam_role.mwaa[0].id
  policy      = data.aws_iam_policy_document.mwaa.json
}

resource "aws_iam_role_policy_attachment" "mwaa" {
  for_each   = local.iam_role_additional_policies
  policy_arn = each.value
  role       = aws_iam_role.mwaa[0].id
}

# ---------------------------------------------------------------------------------------------------------------------
# MWAA S3 Bucket
# ---------------------------------------------------------------------------------------------------------------------
#tfsec:ignore:AWS017 tfsec:ignore:AWS002 tfsec:ignore:AWS077
resource "aws_s3_bucket" "mwaa" {
  count = var.create_s3_bucket ? 1 : 0

  bucket_prefix = var.source_bucket_name != null ? var.source_bucket_name : format("%s-%s-", "mwaa", data.aws_caller_identity.current.account_id)
  tags          = var.tags
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "mwaa" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.mwaa[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "mwaa" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.mwaa[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "mwaa" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.mwaa[0].id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# ---------------------------------------------------------------------------------------------------------------------
# MWAA Security Group
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "mwaa" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "mwaa-"
  description = "Security group for MWAA environment"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_security_group_rule" "mwaa_sg_inbound" {
  count = var.create_security_group ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "all"
  source_security_group_id = aws_security_group.mwaa[0].id
  security_group_id        = aws_security_group.mwaa[0].id
  description              = "Amazon MWAA inbound access"
}

resource "aws_security_group_rule" "mwaa_sg_inbound_vpn" {
  count = var.create_security_group && length(var.source_cidr) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.source_cidr
  security_group_id = aws_security_group.mwaa[0].id
  description       = "VPN Access for Airflow UI"
}

#tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "mwaa_sg_outbound" {
  count = var.create_security_group ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mwaa[0].id
  description       = "Amazon MWAA outbound access"
}