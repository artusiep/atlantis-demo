variable "region" {
  type        = string
  default     = "europe-west1"
  description = <<EOF
Region in which to create the cluster and run Atlantis.
EOF
}

variable "project" {
  type        = string
  description = <<EOF
Project ID where Terraform is authenticated to run to create additional
projects.
EOF
}

variable "project_services" {
  type = list(string)

  default = [
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "sqladmin.googleapis.com"
  ]
}

#
# Atlantis
# --------

variable "service_account" {
  type        = string
  description = <<EOF
Service Account that atlantis will be using to apply changes
EOF
}

variable "atlantis_namespace" {
  type        = string
  default     = "atlantis"
  description = <<EOF
Name that will be used across created resources e.g. pods, services, certificates etc
EOF
}

variable "atlantis_container" {
  type        = string
  default     = "runatlantis/atlantis:latest"
  description = <<EOF
Name of the Atlantis container image to deploy. This can be specified like
"container:version" or as a full container URL.
EOF
}

variable "dns_name" {
  type        = string
  description = <<EOF
DNS name for Atlantis web server
EOF
}

variable "dns_zone_name" {
  type        = string
  description = <<EOF
Cloud DNS name that is used to set up var.dns_name - Domain for Atlantis web server
EOF
}

variable "atlantis_repo_allowlist" {
  type        = string
  description = <<EOF
Whitelist for what repos Atlantis will operate on. This is specified as the
full repo URL or a wildcard splay (e.g. github.com/artusiep/*) or accepts a comma separated list.

Depending on 'is_using_github_app' param after adding to atlantis_repo_allowlist
new repository there is a need to enable notifications to atlantis it can be done either:
 - using github app
 - directly in github repository settings
SEE MORE: https://www.runatlantis.io/docs/server-configuration.html#repo-allowlist
EOF
}

variable "atlantis_repo_config_json" {
  type        = string
  description = <<EOF
Whitelist for what repos Atlantis will operate on. This is specified as the
full repo URL or a wildcard splay (e.g. github.com/artusiep/*).
EOF
}

#########################
# There are 2 ways of running Atlantis
# Github App - doing operations by Github App
# Github User - doing operations by technical Github user
#########################

variable "is_using_github_app" {
  type = bool
}

######################### Variables used in Github App approach
# https://www.runatlantis.io/docs/access-credentials.html#github-app

variable "atlantis_github_app_id" {
  type = string
}

variable "atlantis_github_app_key" {
  type      = string
  sensitive = true
}

variable "atlantis_github_org" {
  type        = string
  description = <<EOF
GitHub organization for Atlantis.
EOF
}

######################### Variables used in Github User approach
# https://www.runatlantis.io/docs/access-credentials.html#generating-an-access-token

variable "atlantis_github_user" {
  type        = string
  description = <<EOF
GitHub username for Atlantis.
EOF
}

variable "atlantis_github_user_token" {
  type        = string
  description = <<EOF
GitHub token for Atlantis user. You can generate it https://github.com/settings/tokens
EOF
}

