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

# 03-bigquery.R -----------------------------------------------------------
# Example of interacting with Google BigQuery with the package 
# bigrquery https://bigrquery.r-dbi.org/index.html

## set constants -----------------------------------------------------------
email <- "your-email@company.com"
project_id <- "your-project-id"
dataset <- "bank_marketing"
table <- "raw"
query <- sprintf("SELECT * FROM `%s.%s.%s`",
                 project_id, dataset, table)

## load packages -----------------------------------------------------------
library(bigrquery)

## authenticate ------------------------------------------------------------
bq_auth(email = email,
        scopes = c("https://www.googleapis.com/auth/cloud-platform"))

## List Datasets  -----------------------------------------------------
bq_project_datasets(project_id)

## list Tables of specific dataset -----------------------------------------
bq_dataset_tables(bq_dataset(project_id, dataset))

## Query table -----------------------------------------------------
query_results <- bq_project_query(project_id, query)

## Download query results -----------------------------------------------------
data_raw <- bq_table_download(query_results)

## inspect downloaded results -------------------------------------------------
summary(data_raw)
head(data_raw)

## Create new Dataset -----------------------------------------------------
dataset_to_create <- bq_dataset(project_id, "rstudiocwtest")
bq_dataset_create(dataset_to_create, location = "US")

### list to confirm creation --------------------------------------------------
bq_project_datasets(project_id)

## Create new empty table -----------------------------------------------------
### name of bq table to create, save as object -----------------------------
bq_table_to_create <- bq_table(project_id, "rstudiocwtest", "californiahousing")
### set fields / schema -----------------------------------------------------
bq_fields_to_create <- as_bq_fields(
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
## execute create table -----------------------------------------------------
bq_table_create(bq_table_to_create,
                bq_fields_to_create)

## list tables to confirm creation ------------------------------------------
bq_dataset_tables(bq_dataset(project_id, dataset))

# cleanup -----------------------------------------------------------------
## delete dataset and all underlying tables -------------------------------
bq_dataset_delete(dataset_to_create, delete_contents = TRUE)

## list datasets to confirm deletion --------------------------------------
bq_project_datasets(project_id)
