resource "google_project_service" "service" {
  for_each = toset(var.project_services)
  project  = var.project
  service  = each.key

  # Do not disable the service on destroy. On destroy, we are going to
  # destroy the project, but we need the APIs available to destroy the
  # underlying resources.
  disable_on_destroy = false
}

resource "google_compute_global_address" "address" {
  name    = var.atlantis_namespace
  project = var.project

  depends_on = [google_project_service.service]
}


resource "google_compute_managed_ssl_certificate" "default" {
  name = "${var.atlantis_namespace}-cert"
  managed {
    domains = ["www.${var.dns_name}.", "${var.dns_name}."]
  }
}

resource "google_dns_record_set" "www_set" {
  name         = "www.${var.dns_name}."
  type         = "CNAME"
  ttl          = 3600
  managed_zone = var.dns_zone_name
  rrdatas      = ["${var.dns_name}."]
}

resource "google_dns_record_set" "set" {
  name         = "${var.dns_name}."
  type         = "A"
  ttl          = 3600
  managed_zone = var.dns_zone_name
  rrdatas      = [google_compute_global_address.address.address]
}

output "project" {
  value = var.project
}

output "region" {
  value = var.region
}

output "address" {
  value = google_compute_global_address.address.address
}
