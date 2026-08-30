resource "aws_iam_policy" "glue_s3_access" {
  name        = "${local.name_prefix}-glue-s3-access"
  description = "Allows FreightHero Glue jobs to access pipeline data and scripts"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListDataBuckets"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = concat(
          [
            for bucket in aws_s3_bucket.data :
            bucket.arn
          ],
          [
            aws_s3_bucket.scripts.arn
          ]
        )
      },
      {
        Sid    = "AccessDataObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = concat(
          [
            for bucket in aws_s3_bucket.data :
            "${bucket.arn}/*"
          ],
          [
            "${aws_s3_bucket.scripts.arn}/*"
          ]
        )
      }
    ]
  })

  tags = local.common_tags
}


resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = aws_iam_policy.glue_s3_access.arn
}


resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}