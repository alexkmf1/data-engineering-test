resource "aws_s3_object" "bronze_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "bronze/ingestion.py"
  source = "${path.module}/../src/bronze/ingestion.py"

  etag = filemd5(
    "${path.module}/../src/bronze/ingestion.py"
  )
}

resource "aws_s3_object" "silver_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "silver/transformation.py"
  source = "${path.module}/../src/silver/transformation.py"

  etag = filemd5(
    "${path.module}/../src/silver/transformation.py"
  )
}

resource "aws_s3_object" "gold_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "gold/build.py"
  source = "${path.module}/../src/gold/build.py"

  etag = filemd5(
    "${path.module}/../src/gold/build.py"
  )
}