# The implemented local pipeline remains notebook-based. Before a real Glue
# deployment, CI/CD would package that logic as executable Python/PySpark files
# and publish the files below to the scripts bucket.
locals {
  glue_script_keys = {
    bronze = "bronze/ingestion.py"
    silver = "silver/transformation.py"
    gold   = "gold/build.py"
  }
}
