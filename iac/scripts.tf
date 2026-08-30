resource "aws_s3_object" "bronze_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "bronze/ingestion_pyspark.py"
  source = "${path.module}/../src/bronze/ingestion_pyspark.py"

  etag = filemd5(
    "${path.module}/../src/bronze/ingestion_pyspark.py"
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