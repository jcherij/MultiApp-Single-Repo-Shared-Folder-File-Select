output "ingest_service_url" {
  value = google_cloud_run_v2_service.ingest.uri
}

output "vitals_topic" {
  value = google_pubsub_topic.vitals.id
}

output "vitals_dlq_topic" {
  value = google_pubsub_topic.vitals_dlq.id
}

output "kms_key_id" {
  value = google_kms_crypto_key.carepulse.id
}
