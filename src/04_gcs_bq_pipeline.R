# Copyright 2023 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Example data pipeline using Google Cloud Storage and BigQuery --------------
# packages used: googleCloudStorageR and bigrquery
# https://code.markedmondson.me/googleCloudStorageR/
# https://bigrquery.r-dbi.org/index.html

# set constants --------------------------------------------------------------
## for authentication 
email <- "your-email@company.com"
project_id <- "your-project-id"

## for this session
timestamp <- strftime(Sys.time(), "%Y%m%d%H%M%S")
bucket_name <- sprintf("%s-%s", project_id, timestamp)

# load packages -----------------------------------------------------------
library(googleCloudStorageR)
library(bigrquery)
library(gargle)

# authenticate ------------------------------------------------------------
## same scope for each R package and use token based auth
### GCS - https://code.markedmondson.me/googleCloudStorageR/articles/googleCloudStorageR.html#token-authentication-1
### BQ - https://bigrquery.r-dbi.org/reference/bq_auth.html
scope <- c("https://www.googleapis.com/auth/cloud-platform")
token <- token_fetch(scopes = scope,
                     email = email)

## authenticate with each service 
gcs_auth(token = token)
bq_auth(token = token)

## List gcs buckets
gcs_list_buckets(project_id)

## List bigquery datasets 
bq_project_datasets(project_id)

# example pipeline  ---------------------------------------------------
## 1 - create new gcs bucket 
## https://code.markedmondson.me/googleCloudStorageR/reference/gcs_create_bucket.html
gcs_create_bucket(name = bucket_name, 
                  projectId = project_id, 
                  location = "US")

### download a copy of the file from public bucket for uploading to own our bucket
data_uri_source <- paste("gs://cloud-samples-data",
                         "/ai-platform-unified/datasets/tabular",
                         "/california-housing-tabular-regression.csv", sep = "")
data_source <- gcs_get_object(object_name = data_uri_source)

### upload data to newly created bucket
data_filename <- "california-housing-tabular-regression.csv"
gcs_upload(data_source,
           bucket = bucket_name,
           name = data_filename,
           predefinedAcl = "bucketLevel")

### check to confirm file uploaded
gcs_list_objects(bucket = bucket_name)

## 4 - create bq dataset 
bq_dataset <- bq_dataset(project_id, "california_housing")
bq_dataset_create(bq_dataset, location = "US")

### create bq table
bq_table <- bq_table(project_id, "california_housing", "data_source")
bq_fields <- as_bq_fields(
  list(
    list(name = "longitude", type = "string"),
    list(name = "latitude", type = "string"),
    list(name = "housing_median_age", type = "string"),
    list(name = "total_rooms", type = "string"),
    list(name = "total_bedrooms", type = "string"),
    list(name = "population", type = "string"),
    list(name = "households", type = "string"),
    list(name = "median_income", type = "string"),
    list(name = "median_house_value", type = "string")
  )
)

### execute table creation 
bq_table_create(bq_table,
                bq_fields)

### sanity check table exists 
bq_table_meta(bq_table)

## 5- load data from GCS to BQ table
### execute table load
bq_table_load(bq_table,
              source_uris = sprintf("gs://%s/%s",
                                    bucket_name,
                                    data_filename),
              source_format = "CSV",
              nskip = 1,
              create_disposition = "CREATE_IF_NEEDED",
              write_disposition = "WRITE_TRUNCATE")

## cleanup --------------------------------------------------------------------
### GCS 
### delete file in GCS bucket & confirm deletion
gcs_delete_object(
  object_name = paste0("gs://", 
                       bucket_name, 
                       "/california-housing-tabular-regression.csv"))
gcs_list_objects(bucket = bucket_name)

### delete bucket & confirm deletion
gcs_delete_bucket(bucket = bucket_name)
gcs_list_buckets(project_id)

### BQ 
## delete dataset and all underlying tables
## https://bigrquery.r-dbi.org/reference/api-dataset.html
bq_dataset_delete("california_housing", delete_contents = TRUE)

## list datasets to confirm deletion
bq_project_datasets(project_id)