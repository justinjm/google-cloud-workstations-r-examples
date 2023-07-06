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

# 01-gargle-auth-setup.R---------------------------------------------------
# Example of authentication with Google Cloud with the package gargle 
# https://gargle.r-lib.org/#gargle

## set constants -----------------------------------------------------------
email <- "your-email@your-company-name.com"
project_id <- "your-project-id"

## load packages -----------------------------------------------------------
library(googleCloudStorageR)
library(bigrquery)
library(gargle)

## set scopes -------------------------------------------------------------
## to enable access for each R package and use token based auth to simplify 
## GCS - https://code.markedmondson.me/googleCloudStorageR/articles/googleCloudStorageR.html#token-authentication-1
## BQ - https://bigrquery.r-dbi.org/reference/bq_auth.html
scope <- c("https://www.googleapis.com/auth/cloud-platform")
token <- token_fetch(scopes = scope, email = email)

## authenticate ------------------------------------------------------------
### authenticate with each service  ----------------------------------------
gcs_auth(token = token)
bq_auth(token = token)

## test connections --------------------------------------------------------
### List gcs buckets --------------------------------------------------------
buckets <- gcs_list_buckets(project_id)
buckets

### List bigquery datasets -------------------------------------------------
datasets <- bq_project_datasets(project_id)
datasets