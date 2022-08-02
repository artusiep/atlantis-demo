terraform {
  required_version = "~> 1.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.4"
    }
  }
}

data "google_billing_account" "acct" {
  display_name = "Moje konto rozliczeniowe"
  open         = true
}

locals {
  region          = "europe-west3"
  project         = "artusiep-secure"
}

provider "google" {
  region  = local.region
  project = local.project
}

resource "google_project" "artusiep_secure" {
  name            = local.project
  project_id      = local.project
  billing_account = data.google_billing_account.acct.id

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

