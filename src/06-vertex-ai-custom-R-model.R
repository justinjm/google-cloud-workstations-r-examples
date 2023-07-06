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

# Example Vertex AI Custom Training for R Workflow ---------------------------
# see notebook version here: 
# https://github.com/GoogleCloudPlatform/vertex-ai-samples/blob/5cc8751c2019344d1b50b182d380765567d14fd1/notebooks/community/ml_ops/stage2/get_started_vertex_training_r_using_r_kernel.ipynb

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

## load reticulate package and set python -----------------------------------
library(reticulate)
use_python(Sys.which("python3"))

## initialize Vertex SDK ------------------------------------------------
aiplatform <- import("google.cloud.aiplatform")

aiplatform$init(project = PROJECT_ID, location = REGION, staging_bucket = BUCKET_URI)

## enable artifact registry ------------------------------------------------
sh("gcloud services enable artifactregistry.googleapis.com")

## create docker repo ------------------------------------------------
PRIVATE_REPO < -"my-docker-repo"

sh(
  'gcloud artifacts repositories create {PRIVATE_REPO} --repository-format=docker --location={REGION} --description="Docker repository"'
)

sh("gcloud artifacts repositories list")

## configure auth ------------------------------------------------
sh("gcloud auth configure-docker {REGION}-docker.pkg.dev --quiet")

## create dockerfile ------------------------------------------------
dir.create("src", showWarnings = FALSE)

## create training script ------------------------------------------------
Dockerfile <- cat("
# filename: Dockerfile - container specifications for using R in Vertex AI
FROM gcr.io/deeplearning-platform-release/r-cpu.4-1:latest

WORKDIR /root

COPY train.R /root/train.R
COPY serve.R /root/serve.R

# Install Fortran
RUN apt-get update
RUN apt-get install gfortran -yy

# Install R packages
RUN Rscript -e \"install.packages('plumber')\"
RUN Rscript -e \"install.packages('randomForest')\"

EXPOSE 8080
", file = "src/Dockerfile")


cat('
#!/usr/bin/env Rscript
# filename: train.R - train a Random Forest model on Vertex AI Managed Dataset
library(tidyverse)
library(data.table)
library(randomForest)
Sys.getenv()

# The GCP Project ID
project_id <- Sys.getenv("CLOUD_ML_PROJECT_ID")

# The GCP Region
location <- Sys.getenv("CLOUD_ML_REGION")

# The Cloud Storage URI to upload the trained model artifact to
model_dir <- Sys.getenv("AIP_MODEL_DIR")

# Next, you create directories to download our training, validation, and test set into.
dir.create("training")
dir.create("validation")
dir.create("test")

# You download the Vertex AI managed data sets into the container environment locally.
system2("gsutil", c("cp", Sys.getenv("AIP_TRAINING_DATA_URI"), "training/"))
system2("gsutil", c("cp", Sys.getenv("AIP_VALIDATION_DATA_URI"), "validation/"))
system2("gsutil", c("cp", Sys.getenv("AIP_TEST_DATA_URI"), "test/"))

# For each data set, you may receive one or more CSV files that you will read into data frames.
training_df <- list.files("training", full.names = TRUE) %>% map_df(~fread(.))
validation_df <- list.files("validation", full.names = TRUE) %>% map_df(~fread(.))
test_df <- list.files("test", full.names = TRUE) %>% map_df(~fread(.))

print("Starting Model Training")
rf <- randomForest(median_house_value ~ ., data=training_df, ntree=100)
rf

saveRDS(rf, "rf.rds")
system2("gsutil", c("cp", "rf.rds", model_dir))
', file = "src/train.R")

## create serving script ------------------------------------------------
cat('
#!/usr/bin/env Rscript
# filename: serve.R - serve predictions from a Random Forest model
Sys.getenv()
library(plumber)

system2("gsutil", c("cp", "-r", Sys.getenv("AIP_STORAGE_URI"), "."))
system("du -a .")

rf <- readRDS("artifacts/rf.rds")
library(randomForest)

predict_route <- function(req, res) {
    print("Handling prediction request")
    df <- as.data.frame(req
instances)
    preds <- predict(rf, df)
    return(list(predictions=preds))
}

print("Staring Serving")

pr() %>%
    pr_get(Sys.getenv("AIP_HEALTH_ROUTE"), function() "OK") %>%
    pr_post(Sys.getenv("AIP_PREDICT_ROUTE"), predict_route) %>%
    pr_run(host = "0.0.0.0", port=as.integer(Sys.getenv("AIP_HTTP_PORT", 8080)))
', file = "src/serve.R")

## build docker container ------------------------------------------------
sh("gcloud builds submit --region={REGION} --tag={IMAGE_URI} --timeout=1h ./src")

## Create Vertex AI Managed Dataset -------------------------------------------
data_uri <- "gs://cloud-samples-data/ai-platform-unified/datasets/tabular/california-housing-tabular-regression.csv"

dataset <- aiplatform$TabularDataset$create(
  display_name = "California Housing Dataset",
  gcs_source = data_uri
)

## create Vertex AI custom training job --------------------------------------
job <- aiplatform$CustomContainerTrainingJob(
  display_name = "vertex-r",
  container_uri = IMAGE_URI,
  command = c("Rscript", "train.R"),
  model_serving_container_command = c("Rscript", "serve.R"),
  model_serving_container_image_uri = IMAGE_URI
)

## execute custom training job ------------------------------------------------
model <- job$run(
  dataset = dataset,
  model_display_name = "vertex-r-model",
  machine_type = "n1-standard-4"
)

model$display_name$model_resource_name
model$uri

## create endpoint ------------------------------------------------------------
endpoint <- aiplatform$Endpoint$create(
  display_name = "California Housing Endpoint",
  project = PROJECT_ID,
  location = REGION
)
endpoint

## deploy to endpoint ---------------------------------------------------------
model$deploy(
  endpoint = endpoint, 
  machine_type = "n1-standard-4"
)

## create example data for prediction request -------------------------------
data_raw <- read.csv(text = sh("gsutil cat {data_uri}", intern = TRUE))

## convert all to string values to build correct prediction request -----------
data <- as.data.frame(lapply(data_raw, as.character))

## build list of 5 examples/rows only for testing -----------------------------
instances <- list(instances = head(data[, names(data) != "median_house_value"], 5))

## convert to required format of JSON
json_instances <- toJSON(instances, auto_unbox = TRUE)

## set parameters for prediction request here so easier to understand --------
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
dataset$delete()
job$delete()

sh("rm -rf src")

### remove Docker image
sh("docker rmi {IMAGE_URI}")

if (delete_bucket == TRUE) sh("gsutil -m rm -r {BUCKET_URI}")