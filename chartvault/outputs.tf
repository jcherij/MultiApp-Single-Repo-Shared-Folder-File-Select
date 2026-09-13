output "archive_bucket_name" {
  value = google_storage_bucket.chart_archive.name
}

output "chart_events_topic" {
  value = google_pubsub_topic.chart_events.id
}

output "kms_key_id" {
  value = google_kms_crypto_key.chartvault.id
}
