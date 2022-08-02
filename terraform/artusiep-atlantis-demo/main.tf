terraform {
  required_version = "~> 1.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12"
    }
  }
}

terraform {
  backend "gcs" {
    bucket = "artusiep-terraform-state"
    prefix = "atlantis"
  }
}

locals {
  region          = "europe-west3"
  project         = "artusiep-atlantis-demo"
  billing_account = "015ED4-E4FEC0-B83F49"
}

provider "google" {
  region  = local.region
  project = local.project
}

resource "google_project" "demo" {
  name            = local.project
  project_id      = local.project
  billing_account = local.billing_account
}

resource "google_project_service" "service" {
  for_each = toset([
    "secretmanager.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "dns.googleapis.com"
  ])
  project = google_project.demo.project_id
  service = each.key

  # Do not disable the service on destroy. On destroy, we are going to
  # destroy the project, but we need the APIs available to destroy the
  # underlying resources.
  disable_on_destroy = false
}

data "google_container_engine_versions" "versions" {
  project  = google_project.demo.project_id
  location = local.region
}

resource "google_container_cluster" "cluster" {
  name               = "atlanits-demo"
  project            = google_project.demo.project_id
  location           = local.region
  enable_autopilot   = true
  min_master_version = data.google_container_engine_versions.versions.default_cluster_version

  ip_allocation_policy {
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  depends_on = [
    google_project_service.service,
  ]
}

# KUBERNETES & ATLANTIS SPECIFIC RESOURCES

data "google_client_config" "current" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.cluster.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.cluster.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}

data "google_secret_manager_secret_version" "atlantis_github_user_token" {
  project = local.project
  secret  = "atlantis_github_user_token"
}

resource "google_service_account" "atlantis_service_account" {
  project      = local.project
  account_id   = "atlantis"
  display_name = "Atlantis service account"
}

resource "google_project_iam_member" "project" {
  for_each = toset([
    local.project,
    "artusiep-secure",
    "artusiep-worker-1",
  ])
  project = each.key
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.atlantis_service_account.email}"
}

resource "google_service_account_iam_binding" "workload_identiy_user" {
  service_account_id = google_service_account.atlantis_service_account.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:artusiep-atlantis-demo.svc.id.goog[default/atlantis]",
  ]
}

module "atlantis" {
  source  = "../modules/atlantis"
  project = google_project.demo.project_id
  region  = local.region

  service_account            = google_service_account.atlantis_service_account.email
  is_using_github_app        = false
  atlantis_github_app_id     = ""
  atlantis_github_app_key    = ""
  atlantis_github_org        = ""
  atlantis_github_user       = "artusiep"
  atlantis_github_user_token = data.google_secret_manager_secret_version.atlantis_github_user_token.secret_data
  atlantis_repo_allowlist    = "github.com/artusiep/atlantis-demo"
  dns_name                   = "atlantis.google.siepietowski.pl"
  dns_zone_name              = "google-siepietowski-pl"
  atlantis_container         = "ghcr.io/runatlantis/atlantis:v0.19.6"
  atlantis_repo_config_json  = <<EOF
    {
      "repos":[
        {
          "id": "github.com/artusiep/atlantis-demo",
          "apply_requirements": ["approved","mergeable"]
        }
      ]
    }
  EOF
}

output "webhook_secret" {
  value     = module.atlantis.webhook_secret
  sensitive = true
}

output "url" {
  value = module.atlantis.url
}
