terraform {
  required_version = "~> 1.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.4"
    }
  }
}


locals {
  region          = "europe-west3"
  project         = "artusiep-secure"
  billing_account = "015ED4-E4FEC0-B83F49"
}

provider "google" {
  region  = local.region
  project = local.project
}

resource "google_project" "artusiep_secure" {
  name            = local.project
  project_id      = local.project
  billing_account = local.billing_account

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket" "state_bucket" {
  name     = "artusiep-terraform-state"
  location = "EU"
  project  = google_project.artusiep_secure.project_id

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

