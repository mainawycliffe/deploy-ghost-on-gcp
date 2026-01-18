terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Uncomment to use GCS backend for state management
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "ghost-cms"
  # }
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Base name for all resources (e.g., 'ghost-cms', 'my-blog')"
  type        = string
  default     = "ghost-cms"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.service_name))
    error_message = "Service name must start with a letter, contain only lowercase letters, numbers, and hyphens, and be 1-63 characters long."
  }
}

variable "ghost_url" {
  description = "Public URL for Ghost blog (optional, defaults to Cloud Run URL)"
  type        = string
  default     = ""
}

variable "database_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

variable "mail_from" {
  description = "From email address for Ghost"
  type        = string
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Enable deletion protection for Cloud SQL instance (set to false for testing)"
  type        = bool
  default     = true
}

variable "enable_cdn" {
  description = "Enable Cloud CDN in front of Cloud Run (optional, defaults to true)"
  type        = bool
  default     = true
}

# Provider Configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Service Account for Ghost Cloud Run
resource "google_service_account" "ghost_sa" {
  account_id   = "${var.service_name}-sa"
  display_name = "${var.service_name} Service Account"
  description  = "Service account for ${var.service_name} running on Cloud Run"
}

# Grant Cloud SQL Client role to service account
resource "google_project_iam_member" "ghost_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.ghost_sa.email}"
}

# Cloud Storage Bucket for Ghost content
resource "google_storage_bucket" "ghost_content" {
  name          = "${var.project_id}-${var.service_name}-content-${random_id.suffix.hex}"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  cors {
    origin          = [var.ghost_url != "" ? var.ghost_url : "*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

# IAM binding for service account to access bucket
resource "google_storage_bucket_iam_member" "ghost_storage_admin" {
  bucket = google_storage_bucket.ghost_content.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ghost_sa.email}"
}

# Make bucket publicly readable for images
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.ghost_content.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Generate random database password
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store database password in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.service_name}-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# IAM binding for service account to access secret
resource "google_secret_manager_secret_iam_member" "ghost_secret_accessor" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ghost_sa.email}"
}

# Cloud SQL MySQL Instance
resource "google_sql_database_instance" "ghost_db" {
  name             = "${var.service_name}-db-${random_id.suffix.hex}"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier              = var.database_tier
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = 10
    disk_autoresize   = true

    backup_configuration {
      enabled            = false
      binary_log_enabled = false
    }

    ip_configuration {
      ipv4_enabled = true
      # Public IP enabled to allow Cloud Run connector; no inbound networks are opened.
    }

    database_flags {
      name  = "character_set_server"
      value = "utf8mb4"
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = var.deletion_protection

  depends_on = [google_project_service.required_apis]
}

# Cloud SQL Database
resource "google_sql_database" "ghost_database" {
  name     = "ghost_production"
  instance = google_sql_database_instance.ghost_db.name
  charset  = "utf8mb4"
}

# Cloud SQL User
resource "google_sql_user" "ghost_user" {
  name     = "ghost"
  instance = google_sql_database_instance.ghost_db.name
  password = random_password.db_password.result
}

# Artifact Registry Repository for Docker images
resource "google_artifact_registry_repository" "ghost_repo" {
  location      = var.region
  repository_id = var.service_name
  description   = "Docker repository for ${var.service_name}"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Build Docker image using Cloud Build
resource "terraform_data" "build_ghost_image" {
  # Trigger rebuild when Dockerfile or config changes
  triggers_replace = {
    dockerfile_hash = filemd5("${path.module}/../Dockerfile")
    config_hash     = filemd5("${path.module}/../config.production.json")
    entrypoint_hash = filemd5("${path.module}/../docker-entrypoint.sh")
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds submit \
        --config=${path.module}/../cloudbuild.yaml \
        --substitutions=_REGION=${var.region},_REPO_ID=${var.service_name},_SERVICE_NAME=${var.service_name},_TAG=latest \
        --project=${var.project_id} \
        ${path.module}/..
    EOT
  }

  depends_on = [
    google_artifact_registry_repository.ghost_repo,
    google_project_service.required_apis
  ]
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "ghost" {
  name     = var.service_name
  location = var.region

  template {
    service_account = google_service_account.ghost_sa.email

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      # Image will be updated by deploy.sh script
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.ghost_repo.repository_id}/${var.service_name}:latest"

      ports {
        container_port = 2368
      }

      resources {
        limits = {
          cpu    = "0.5"
          memory = "512Mi"
        }
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "GHOST_URL"
        value = var.ghost_url != "" ? var.ghost_url : "https://${var.service_name}-PROJECT_ID.run.app"
      }

      env {
        name  = "DATABASE_SOCKET_PATH"
        value = "/cloudsql/${google_sql_database_instance.ghost_db.connection_name}"
      }

      env {
        name  = "DATABASE_USER"
        value = google_sql_user.ghost_user.name
      }

      env {
        name  = "DATABASE_NAME"
        value = google_sql_database.ghost_database.name
      }

      env {
        name = "DATABASE_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.ghost_content.name
      }

      env {
        name  = "GCS_ASSET_DOMAIN"
        value = "https://storage.googleapis.com/${google_storage_bucket.ghost_content.name}"
      }

      env {
        name  = "GHOST_MAIL_FROM"
        value = var.mail_from
      }

      env {
        name  = "GHOST_MAIL_TRANSPORT"
        value = "Direct"
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    timeout = "300s"

    # Enable Cloud SQL connection
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.ghost_db.connection_name]
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.required_apis,
    google_sql_database.ghost_database,
    google_sql_user.ghost_user,
    terraform_data.build_ghost_image,
  ]
}

# Make Cloud Run service publicly accessible
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.ghost.location
  name     = google_cloud_run_v2_service.ghost.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud CDN Configuration (optional, enabled by default)
resource "google_compute_network_endpoint_group" "ghost_neg" {
  count                 = var.enable_cdn ? 1 : 0
  name                  = "${var.service_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.ghost.name
  }

  depends_on = [google_cloud_run_v2_service.ghost]
}

resource "google_compute_backend_service" "ghost_backend" {
  count                           = var.enable_cdn ? 1 : 0
  name                            = "${var.service_name}-backend"
  protocol                        = "HTTPS"
  port_name                       = "http"
  timeout_sec                     = 30
  enable_cdn                      = true
  session_affinity                = "NONE"
  connection_draining_timeout_sec = 300

  backend {
    group = google_compute_network_endpoint_group.ghost_neg[0].id
  }

  # Health check for Cloud Run
  health_checks = [google_compute_health_check.ghost_health_check[0].id]

  # CDN policy configuration (optimized for cost)
  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
    # Aggressive caching for static content reduces origin requests
    client_ttl       = 86400   # 24 hours - clients cache for max time
    default_ttl      = 604800  # 7 days - origin cache by default
    max_ttl          = 2592000 # 30 days - max cache duration
    negative_caching = true
    # Longer negative caching reduces error-related origin hits
    negative_caching_policy {
      code = 404
      ttl  = 3600 # 1 hour for not found
    }
    negative_caching_policy {
      code = 410
      ttl  = 86400 # 24 hours for gone
    }
  }

  depends_on = [google_compute_network_endpoint_group.ghost_neg]
}

resource "google_compute_health_check" "ghost_health_check" {
  count               = var.enable_cdn ? 1 : 0
  name                = "${var.service_name}-health-check"
  check_interval_sec  = 30 # Reduced from 10s to minimize health check costs
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  https_health_check {
    port         = "443"
    request_path = "/ghost/api/v3/site/"
  }
}

resource "google_compute_url_map" "ghost_url_map" {
  count           = var.enable_cdn ? 1 : 0
  name            = "${var.service_name}-url-map"
  default_service = google_compute_backend_service.ghost_backend[0].id
}

resource "google_compute_ssl_certificate" "ghost_cert" {
  count = var.enable_cdn ? 1 : 0
  name  = "${var.service_name}-cert"
  managed {
    domains = [var.ghost_url != "" ? var.ghost_url : null]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_compute_target_https_proxy" "ghost_https_proxy" {
  count            = var.enable_cdn ? 1 : 0
  name             = "${var.service_name}-https-proxy"
  url_map          = google_compute_url_map.ghost_url_map[0].id
  ssl_certificates = [google_compute_ssl_certificate.ghost_cert[0].id]
  ssl_policy       = google_compute_ssl_policy.ghost_ssl_policy[0].id
}

resource "google_compute_ssl_policy" "ghost_ssl_policy" {
  count           = var.enable_cdn ? 1 : 0
  name            = "${var.service_name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_http_proxy" "ghost_http_proxy" {
  count   = var.enable_cdn ? 1 : 0
  name    = "${var.service_name}-http-proxy"
  url_map = google_compute_url_map.ghost_url_map[0].id
}

resource "google_compute_global_forwarding_rule" "ghost_https" {
  count                 = var.enable_cdn ? 1 : 0
  name                  = "${var.service_name}-https-lb"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.ghost_https_proxy[0].id
}

resource "google_compute_global_forwarding_rule" "ghost_http" {
  count                 = var.enable_cdn ? 1 : 0
  name                  = "${var.service_name}-http-lb"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.ghost_http_proxy[0].id
}

# Outputs
output "cloud_run_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.ghost.uri
}

output "bucket_name" {
  description = "Name of the Cloud Storage bucket"
  value       = google_storage_bucket.ghost_content.name
}

output "database_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.ghost_db.name
}

output "database_connection_name" {
  description = "Connection name for Cloud SQL"
  value       = google_sql_database_instance.ghost_db.connection_name
}

output "artifact_registry_url" {
  description = "URL for Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.ghost_repo.repository_id}"
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.ghost_sa.email
}

output "cdn_ip_address" {
  description = "External IP address of the Cloud CDN load balancer (if enabled)"
  value       = var.enable_cdn ? google_compute_global_forwarding_rule.ghost_https[0].ip_address : null
}

output "cdn_enabled" {
  description = "Whether Cloud CDN is enabled"
  value       = var.enable_cdn
}
