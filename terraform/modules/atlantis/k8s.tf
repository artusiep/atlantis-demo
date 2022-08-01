resource "random_id" "webhook" {
  byte_length = "64"
}

resource "random_password" "password" {
  length           = 32
  special          = true
  override_special = "_%@&"
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    name = var.atlantis_namespace

    annotations = {
      "iam.gke.io/gcp-service-account" : var.service_account
    }
  }
}

resource "kubernetes_secret" "secret" {
  metadata {
    name = var.atlantis_namespace
  }
  data = {
    "atlantis-app-key.pem" = var.atlantis_github_app_key
  }
}

locals {
  default_pod_envs = {
    "ATLANTIS_LOG_LEVEL" : "debug"
    "ATLANTIS_DEFAULT_TF_VERSION" : "1.2.5"
    "ATLANTIS_PORT" : "4141"
    "ATLANTIS_ATLANTIS_URL" : "https://${var.dns_name}"
    "ATLANTIS_GH_ORG" : var.atlantis_github_org
    "ATLANTIS_REPO_ALLOWLIST" : var.atlantis_repo_allowlist
    "GOOGLE_PROJECT" : var.project
    "ATLANTIS_ENABLE_DIFF_MARKDOWN_FORMAT" : "true"
    "ATLANTIS_CHECKOUT_STRATEGY" : "merge"
    "ATLANTIS_WEB_BASIC_AUTH" : "true"
    "ATLANTIS_WEB_USERNAME" : "atlantis"
    "ATLANTIS_WEB_PASSWORD" : random_password.password.result
    "ATLANTIS_HIDE_PREV_PLAN_COMMENTS" : "true"
    "ATLANTIS_REPO_CONFIG_JSON" : var.atlantis_repo_config_json
  }

  github_app_envs = {
    "ATLANTIS_GH_APP_ID" : var.atlantis_github_app_id
    "ATLANTIS_GH_APP_KEY_FILE" : "/etc/atlantis/github/atlantis-app-key.pem"
    "ATLANTIS_WRITE_GIT_CREDS" : "true"
  }

  github_user_envs = {
    "ATLANTIS_GH_USER" : var.atlantis_github_user
    "ATLANTIS_GH_TOKEN" : var.atlantis_github_user_token
    "ATLANTIS_GH_WEBHOOK_SECRET" : random_id.webhook.hex
  }

  pod_envs = var.is_using_github_app ? merge(local.default_pod_envs, local.github_app_envs) : merge(local.default_pod_envs, local.github_user_envs)
}

resource "kubernetes_deployment" "deployment" {
  metadata {
    name   = var.atlantis_namespace
    labels = {
      app = var.atlantis_namespace
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.atlantis_namespace
      }
    }
    template {
      metadata {
        labels = {
          app = var.atlantis_namespace
        }
      }
      spec {
        service_account_name = kubernetes_service_account.service_account.metadata[0].name
        container {
          name  = var.atlantis_namespace
          image = var.atlantis_container
          args  = ["server"]

          port {
            name           = "atlantis"
            container_port = "4141"
            protocol       = "TCP"
          }

          dynamic "env" {
            for_each = local.pod_envs
            content {
              name  = env.key
              value = env.value
            }
          }
          resources {
            limits = {
              cpu               = "500m"
              ephemeral-storage = "1Gi"
              memory            = "1024Mi"
            }
            requests = {
              cpu               = "500m"
              memory            = "1024Mi"
              ephemeral-storage = "1Gi"
            }
          }

          volume_mount {
            name       = var.atlantis_namespace
            mount_path = "/etc/atlantis/github"
            read_only  = true
          }

          readiness_probe {
            initial_delay_seconds = "5"
            period_seconds        = "10"
            timeout_seconds       = "5"

            http_get {
              path   = "/healthz"
              port   = "4141"
              scheme = "HTTP"
            }
          }
          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = false
            run_as_non_root            = false

            capabilities {
              add  = []
              drop = ["NET_RAW"]
            }
          }
        }
        volume {
          name = var.atlantis_namespace
          secret {
            secret_name = kubernetes_secret.secret.metadata[0].name
          }
        }
        security_context {
          run_as_non_root     = false
          supplemental_groups = []

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "service" {
  metadata {
    name = var.atlantis_namespace

    annotations = {
      "cloud.google.com/neg" : "{\"ingress\": true}",
      #      TODO: Enable HTTPS between laod balancer and atlantis https://cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb#https_tls_between_load_balancer_and_your_application
      #      "cloud.google.com/app-protocols": "{\"atlantis-port\":\"HTTPS\"}"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = kubernetes_deployment.deployment.metadata[0].labels.app
    }

    port {
      name        = "atlantis-port"
      port        = "443"
      target_port = "4141"
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "ingress" {
  metadata {
    name = var.atlantis_namespace

    annotations = {
      "kubernetes.io/ingress.class" : "gce",
      "kubernetes.io/ingress.global-static-ip-name" : google_compute_global_address.address.name,
      "ingress.gcp.kubernetes.io/pre-shared-cert" = google_compute_managed_ssl_certificate.default.name
      "kubernetes.io/ingress.allow-http" : "false"
    }
  }
  spec {
    rule {
      http {
        path {
          path = "/*"
          backend {
            service {
              name = kubernetes_service.service.metadata[0].name
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}

output "url" {
  value = "https://${var.dns_name}"
}

output "webhook_secret" {
  value = random_id.webhook.hex
}