resource "aws_s3_object" "bronze_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "bronze/ingestion.ipynb"
  source = "${path.module}/../src/bronze/ingestion.ipynb"

  etag = filemd5(
    "${path.module}/../src/bronze/ingestion.ipynb"
  )
}

resource "aws_s3_object" "silver_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "silver/transformation.ipynb"
  source = "${path.module}/../src/silver/transformation.ipynb"

  etag = filemd5(
    "${path.module}/../src/silver/transformation.ipynb"
  )
}

resource "aws_s3_object" "gold_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "gold/build.ipynb"
  source = "${path.module}/../src/gold/build.ipynb"

  etag = filemd5(
    "${path.module}/../src/gold/build.ipynb"
  )
}