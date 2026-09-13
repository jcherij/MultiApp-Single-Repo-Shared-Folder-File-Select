# Required tag keys per Platform Engineering's Common Application
# Requirements: application, environment, managed-by, data-class.
locals {
  tags = {
    application = var.application
    environment = var.environment
    managed-by  = "terraform"
    data-class  = var.data_class
  }
}

# ---------------------------------------------------------------------------
# 1. Dedicated identity — no default compute service account, per Common
#    Application Requirements.
# ---------------------------------------------------------------------------
resource "google_service_account" "ingest" {
  account_id   = "${var.application}-${var.environment}-ingest"
  display_name = "carepulse vitals ingest (${var.environment})"
}

data "google_project" "current" {
  project_id = var.project_id
}

# Required for the OIDC-authenticated push subscription below: the Pub/Sub
# service agent must be able to mint tokens as the ingest SA, or GCP rejects
# the subscription creation call at apply time (this isn't caught by
# `validate` — it's an API-side check, not a schema check).
resource "google_service_account_iam_member" "pubsub_token_creator" {
  service_account_id = google_service_account.ingest.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ---------------------------------------------------------------------------
# 2. Encryption — CMEK for PHI, not Google-managed default keys.
# ---------------------------------------------------------------------------
resource "google_kms_crypto_key" "carepulse" {
  name            = "${var.application}-${var.environment}"
  key_ring        = var.kms_key_ring_id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# 3-4. Messaging — dead-letter topic required for any queue per platform
#    baseline; ingest topic carries the raw vitals payload.
# ---------------------------------------------------------------------------
resource "google_pubsub_topic" "vitals_dlq" {
  name = "${var.application}-${var.environment}-vitals-dlq"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_topic" "vitals" {
  name = "${var.application}-${var.environment}-vitals"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  kms_key_name = google_kms_crypto_key.carepulse.id
}

# ---------------------------------------------------------------------------
# 5. Push subscription feeding the ingest service, with DLQ wired in.
# ---------------------------------------------------------------------------
resource "google_pubsub_subscription" "vitals_push" {
  name  = "${var.application}-${var.environment}-vitals-push"
  topic = google_pubsub_topic.vitals.id

  push_config {
    push_endpoint = google_cloud_run_v2_service.ingest.uri

    oidc_token {
      service_account_email = google_service_account.ingest.email
    }
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.vitals_dlq.id
    max_delivery_attempts = 5
  }

  ack_deadline_seconds = 30
}

# ---------------------------------------------------------------------------
# 6. Compute — Cloud Run, internal-only ingress, routed through the
#    platform VPC via connector (no public IP path around it).
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "ingest" {
  name     = "${var.application}-${var.environment}-ingest"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.ingest.email

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "ALL_TRAFFIC"
    }

    containers {
      image = var.ingest_image

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
  }

  labels = local.tags
}

# ---------------------------------------------------------------------------
# 7. Invocation restricted to the push subscription's own identity only —
#    not allUsers.
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  name     = google_cloud_run_v2_service.ingest.name
  location = google_cloud_run_v2_service.ingest.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.ingest.email}"
}

# ---------------------------------------------------------------------------
# 8. Least-privilege publish right, scoped to this one topic — not a
#    project-wide Pub/Sub role.
# ---------------------------------------------------------------------------
resource "google_pubsub_topic_iam_member" "ingest_publisher" {
  topic  = google_pubsub_topic.vitals.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.ingest.email}"
}

# ---------------------------------------------------------------------------
# 9. Data Access audit logging — required explicitly for PHI, routed via
#    the org's Cloud Audit Logs (not left on defaults).
# ---------------------------------------------------------------------------
resource "google_project_iam_audit_config" "carepulse" {
  project = var.project_id
  service = "pubsub.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# ---------------------------------------------------------------------------
# 10. Monitoring — required before go-live: error rate on the ingest path.
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "ingest_errors" {
  display_name = "${var.application}-${var.environment}-ingest-errors"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run 5xx rate"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloud_run_v2_service.ingest.name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = var.alert_notification_channels
}
