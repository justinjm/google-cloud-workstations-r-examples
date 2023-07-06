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

# Example Vertex AI AutoML Tabular workflow -------------------------------
# see links below for more details
# https://cloud.google.com/vertex-ai/docs/training-overview
# https://cloud.google.com/vertex-ai/docs/tabular-data/overview
# https://cloud.google.com/vertex-ai/docs/tutorials/tabular-automl/overview

## load packages --------------------------------------------------------------
library(glue)
library(httr) 
library(jsonlite)
library(withr) # for gcloud sdk: https://stackoverflow.com/a/64381848/1812363 

## user defined functions ---------------------------------------------------
### custom function for easier interaction with shell
sh <- function(cmd, args = c(), intern = FALSE) {
  with_path(path.expand("~/google-cloud-sdk/bin/"), {
    if (is.null(args)) {
      cmd <- glue(cmd)
      s <- strsplit(cmd, " ")[[1]]
      cmd <- s[1]
      args <- s[2:length(s)]
    }
    ret <- system2(cmd, args, stdout = TRUE, stderr = TRUE)
    if ("errmsg" %in% attributes(attributes(ret))$names) cat(attr(ret, "errmsg"), "\n")
    if (intern) return(ret) else cat(paste(ret, collapse = "\n"))
  }
  )
}

## set constants ------------------------------------------------
PROJECT_ID <- sh("gcloud config get-value project", intern = TRUE)
REGION <- "us-central1"
BUCKET_URI <- glue("gs://{PROJECT_ID}-vertex-r")
DOCKER_REPO <- "vertex-r"
IMAGE_NAME <- "vertex-r"
IMAGE_TAG <- "latest"
IMAGE_URI <- glue("{REGION}-docker.pkg.dev/{PROJECT_ID}/{DOCKER_REPO}/{IMAGE_NAME}:{IMAGE_TAG}")

## set timestamp for differentiating between runs 
TIMESTAMP <- strftime(Sys.time(), "%Y%m%d%H%M%S")
paste0("timestamp: ", TIMESTAMP)
DATASET_NAME <- sprintf("california-housing-%s", TIMESTAMP)
JOB_NAME <- sprintf("california-housing-%s", TIMESTAMP)
MODEL_NAME <- sprintf("california-housing-model-%s", TIMESTAMP) 

## authenticate ------------------------------------------------
sh("gcloud config set project {PROJECT_ID}")

## create bucket ------------------------------------------------
## use gsutil instead of adding another R package dependency (googleCloudStorageR)
sh("gsutil mb -l {REGION} -p {PROJECT_ID} {BUCKET_URI}")

## load reticulate package and set python version ----------------------------
library(reticulate)
use_python(Sys.which("python3"))

## initialize Vertex SDK ------------------------------------------------------
aiplatform <- import("google.cloud.aiplatform")

aiplatform$init(project = PROJECT_ID, 
                location = REGION, 
                staging_bucket = BUCKET_URI)

## list datasets - tabular ----------------------------------------------------
datasets <- aiplatform$TabularDataset$list()
datasets

## list models ----------------------------------------------------------------
models <- aiplatform$Model$list()
models 

## create dataset - tabular ------------------------------------------------
data_uri <- "gs://cloud-samples-data/ai-platform-unified/datasets/tabular/california-housing-tabular-regression.csv"
dataset <- aiplatform$TabularDataset$create(
  display_name = DATASET_NAME,
  gcs_source = data_uri
)

## train model - automl tabular -----------------------------------------------
job <- aiplatform$AutoMLTabularTrainingJob(
  display_name = JOB_NAME,
  optimization_prediction_type = "regression"
)

model <- job$run(
  dataset = dataset,
  model_display_name = MODEL_NAME,
  target_column = "median_house_value"
)

## print model resource name if needed 
# model$resource_name

## create endpoint ------------------------------------------------------------
endpoint <- aiplatform$Endpoint$create(
  display_name = "California_Housing_Endpoint",
  project = PROJECT_ID,
  location = REGION
)
endpoint

## To use this Endpoint in another session, use resource_name from Endpoint()
## method (e.g - `projects/11111111111111/locations/us-central1/endpoints/111111111111111`)
# endpoint <- aiplatform$Endpoint()

## deploy model to endpoint ---------------------------------------------------
model$deploy(
  endpoint = endpoint, 
  machine_type = "n1-standard-4"
)

## create example data for prediction request  -------------------------------
data_raw <- read.csv(text=sh("gsutil cat {data_uri}", intern = TRUE))

## convert all to string values to build correct prediction request ----------
data <- as.data.frame(lapply(data_raw, as.character))

## build list of 5 examples/rows only for testing ----------------------------
instances <- list(instances=head(data[, names(data) != "median_house_value"], 5))

## convert to required format of JSON ----------------------------------------
json_instances <- toJSON(instances, auto_unbox = TRUE)

## set parameters for prediction request here so easier to understand -------
url <- glue(
  "https://{REGION}-aiplatform.googleapis.com/v1/{endpoint$resource_name}:predict"
)
access_token <- sh("gcloud auth print-access-token", intern = TRUE)

## make prediction request ---------------------------------------------------
sh(
  "curl",
  c(
    "--tr-encoding",
    "-s",
    "-X POST",
    glue("-H 'Authorization: Bearer {access_token}'"),
    "-H 'Content-Type: application/json'",
    url,
    glue("-d '{json_instances}'")
  )
)

## cleanup -----------------------------------------------------------------

delete_bucket = FALSE

endpoint$undeploy_all()
endpoint$delete()
model$delete()
job$delete()
dataset$delete()

### remove Docker image
sh("docker rmi {IMAGE_URI}")

if (delete_bucket == TRUE) sh("gsutil -m rm -r {BUCKET_URI}")