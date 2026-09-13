locals {
  tags = {
    application = var.application
    environment = var.environment
    managed-by  = "terraform"
    data-class  = var.data_class
  }
}

# ---------------------------------------------------------------------------
# 1. Dedicated identity for the archive writer.
# ---------------------------------------------------------------------------
resource "google_service_account" "writer" {
  account_id   = "${var.application}-${var.environment}-writer"
  display_name = "chartvault archive writer (${var.environment})"
}

# ---------------------------------------------------------------------------
# 2-3. Encryption — separate CMEK from carepulse; explicit grant to the
#    writer SA (default project roles don't include key access).
# ---------------------------------------------------------------------------
resource "google_kms_crypto_key" "chartvault" {
  name            = "${var.application}-${var.environment}"
  key_ring        = var.kms_key_ring_id
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "writer_key_access" {
  crypto_key_id = google_kms_crypto_key.chartvault.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.writer.email}"
}

# Required because the function below runs as a custom service account
# rather than the default compute SA: Cloud Functions Gen2 needs the
# runtime SA to hold this role for its Eventarc/Pub/Sub trigger to attach.
# Missing this fails at apply time, not at validate/plan.
resource "google_project_iam_member" "writer_event_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.writer.email}"
}

# ---------------------------------------------------------------------------
# 4. Storage — versioned, CMEK-encrypted, retention-locked for HIPAA's
#    6-year minimum. Can't be accidentally destroyed while holding PHI.
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "chart_archive" {
  name                        = "${var.project_id}-${var.application}-${var.environment}"
  location                    = var.region
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.chartvault.id
  }

  retention_policy {
    retention_period = var.retention_seconds
  }

  labels = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# 5. Least-privilege write access, scoped to this one bucket.
# ---------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "writer_object_creator" {
  bucket = google_storage_bucket.chart_archive.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.writer.email}"
}

# ---------------------------------------------------------------------------
# 6. Trigger — chart-export events land here from upstream systems.
# ---------------------------------------------------------------------------
resource "google_pubsub_topic" "chart_events" {
  name = "${var.application}-${var.environment}-chart-events"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

# ---------------------------------------------------------------------------
# 7-8. Compute — Gen2 function, internal ingress only, writes de-identified
#    exports to the archive bucket.
# ---------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "archive_writer" {
  name     = "${var.application}-${var.environment}-archive-writer"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "write_chart_export"

    source {
      storage_source {
        bucket = var.writer_source_bucket
        object = var.writer_source_object
      }
    }
  }

  service_config {
    service_account_email = google_service_account.writer.email
    ingress_settings      = "ALLOW_INTERNAL_ONLY"
    available_memory      = "256M"

    environment_variables = {
      ARCHIVE_BUCKET = google_storage_bucket.chart_archive.name
      ENVIRONMENT    = var.environment
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.chart_events.id
  }

  labels = local.tags
}

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = var.project_id
  location       = google_cloudfunctions2_function.archive_writer.location
  cloud_function = google_cloudfunctions2_function.archive_writer.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.writer.email}"
}

# ---------------------------------------------------------------------------
# 9. Data Access audit logging for storage — required explicitly for PHI.
# ---------------------------------------------------------------------------
resource "google_project_iam_audit_config" "chartvault" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# ---------------------------------------------------------------------------
# 10. Monitoring — write failures on the archive path.
# ---------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "write_failures" {
  display_name = "${var.application}-${var.environment}-write-failures"
  combiner     = "OR"

  conditions {
    display_name = "archive_writer execution errors"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloudfunctions2_function.archive_writer.name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 3
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = var.alert_notification_channels
}
