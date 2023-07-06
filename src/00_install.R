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

# install.R --------------------------------------------------------------
# install packages from CRAN 

## create list of required packages ----------------------------------------
required_packages <- c(
  "glue", "httr", "jsonlite", "withr", "reticulate", "gargle", 
  "googleAuthR", "googleCloudStorageR","bigrquery"
  )

## install only missing ones  ----------------------------------------------
install.packages(setdiff(required_packages, rownames(installed.packages())))
