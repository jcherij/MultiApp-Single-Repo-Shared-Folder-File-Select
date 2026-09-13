project_id  = "kennari-medtest-prod"
region      = "us-central1"
environment = "production"
data_class  = "phi"

kms_key_ring_id      = "projects/kennari-medtest-prod/locations/us-central1/keyRings/app-keys"
writer_source_bucket = "kennari-medtest-prod-function-sources"
writer_source_object = "chartvault/archive-writer-v1.zip"

alert_notification_channels = [
  "projects/kennari-medtest-prod/notificationChannels/1234567890"
]
