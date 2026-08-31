output "data_buckets" {
  description = "S3 buckets created for each data layer"

  value = {
    for layer, bucket in aws_s3_bucket.data :
    layer => bucket.bucket
  }
}

output "glue_execution_role_arn" {
  description = "IAM role used by AWS Glue"
  value       = aws_iam_role.glue_execution.arn
}

output "glue_jobs" {
  description = "Glue jobs created for the pipeline"

  value = {
    for layer, job in aws_glue_job.pipeline :
    layer => job.name
  }
}