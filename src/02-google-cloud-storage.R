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

# Example of interacting with Google Cloud Storage with the package --------
# googleCloudStorageR: https://code.markedmondson.me/googleCloudStorageR/

# set constants -----------------------------------------------------------
email <- "your-email@your-company-name.com"
project_id <- "your-project-id"
bucket <- "your-bucket-name"

# load packages -----------------------------------------------------------
library(googleCloudStorageR)
library(gargle)

# authenticate ------------------------------------------------------------
scope <- c("https://www.googleapis.com/auth/cloud-platform")
token <- token_fetch(scopes = scope,
                     email = email)

gcs_auth(token = token)

## List buckets
buckets <- gcs_list_buckets(project_id)
buckets

## list objects in buckets
### set global bucket first so we don't need to in future api calls
gcs_global_bucket(bucket)
gcs_list_objects()

## download file from bucket 
data_uri <- "gs://cloud-samples-data/ai-platform-unified/datasets/tabular/california-housing-tabular-regression.csv"
data_raw <- gcs_get_object(object_name = data_uri)

## inspect data to sanity check
summary(data_raw)
head(data_raw)

## upload file to our bucket 
gcs_upload(data_raw,
           name = "california-housing-tabular-regression.csv",
           predefinedAcl = "bucketLevel")

## list to confirm upload 
gcs_list_objects()

## cleanup - delete file
gcs_delete_object(
  paste0("gs://",bucket,"/california-housing-tabular-regression.csv"))

## confrim deletion
gcs_list_objects()
