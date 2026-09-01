locals {
  glue_jobs = {
    bronze = {
      description = "Ingest raw source files into the Bronze data layer"

      script_location = format(
        "s3://%s/%s",
        aws_s3_bucket.scripts.bucket,
        aws_s3_object.bronze_script.key
      )

      source_path = "s3://${aws_s3_bucket.data["landing"].bucket}/"
      target_path = "s3://${aws_s3_bucket.data["bronze"].bucket}/"
    }

    silver = {
      description = "Standardize, validate, and deduplicate Bronze datasets"

      script_location = format(
        "s3://%s/%s",
        aws_s3_bucket.scripts.bucket,
        aws_s3_object.silver_script.key
      )

      source_path = "s3://${aws_s3_bucket.data["bronze"].bucket}/"
      target_path = "s3://${aws_s3_bucket.data["silver"].bucket}/"
    }

    gold = {
      description = "Build the final carrier responsiveness analytical dataset"

      script_location = format(
        "s3://%s/%s",
        aws_s3_bucket.scripts.bucket,
        aws_s3_object.gold_script.key
      )

      source_path = "s3://${aws_s3_bucket.data["silver"].bucket}/"
      target_path = "s3://${aws_s3_bucket.data["gold"].bucket}/"
    }
  }
}

resource "aws_glue_job" "pipeline" {
  for_each = local.glue_jobs

  name        = "${local.name_prefix}-${each.key}-job"
  description = each.value.description
  role_arn    = aws_iam_role.glue_execution.arn

  job_mode       = "SCRIPT"
  glue_version   = "5.1"
  worker_type    = "G.1X"
  number_of_workers = 2

  max_retries = 1
  timeout     = 30

  execution_class          = "STANDARD"
  job_run_queuing_enabled  = true

  execution_property {
    max_concurrent_runs = 1
  }

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = each.value.script_location
  }

  default_arguments = {
    "--job-language"                    = "python"
    "--environment"                     = var.environment
    "--source_path"                     = each.value.source_path
    "--target_path"                     = each.value.target_path
    "--TempDir"                         = "s3://${aws_s3_bucket.data["landing"].bucket}/glue-temp/${each.key}/"
    "--job-bookmark-option"             = "job-bookmark-disable"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-observability-metrics"    = "true"
    "--enable-metrics"                  = ""
  }

  tags = merge(
    local.common_tags,
    {
      DataLayer = each.key
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.glue_s3_access,
    aws_iam_role_policy_attachment.glue_service
  ]
}