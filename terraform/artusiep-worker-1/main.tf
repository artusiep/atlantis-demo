terraform {
  required_version = "~> 1.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.4"
    }
  }
}

terraform {
  backend "gcs" {
    bucket = "artusiep-terraform-state"
    prefix = "artusiep-worker-1"
  }
}


locals {
  region          = "europe-west3"
  project         = "artusiep-worker-1"
  billing_account = "015ED4-E4FEC0-B83F49"
}

provider "google" {
  region  = local.region
  project = local.project
}

resource "google_project" "artusiep_worker_1" {
  name            = local.project
  project_id      = local.project
  billing_account = local.billing_account
}


#resource "google_storage_bucket" "example_bucket" {
#  name     = "artusiep-example-bucket"
#  location = "EU"
#  project  = google_project.artusiep_worker_1.project_id
#}
#
#resource "google_storage_bucket" "state_bucket" {
#  name     = "artusiep-terraform-state"
#  location = "EU"
#  project  = google_project.artusiep_worker_1.project_id
#}
