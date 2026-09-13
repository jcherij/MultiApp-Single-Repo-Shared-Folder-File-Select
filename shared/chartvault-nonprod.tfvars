project_id  = "kennari-medtest-nonprod"
region      = "us-central1"
environment = "staging"
data_class  = "phi"

kms_key_ring_id      = "projects/kennari-medtest-nonprod/locations/us-central1/keyRings/app-keys"
writer_source_bucket = "kennari-medtest-nonprod-function-sources"
writer_source_object = "chartvault/archive-writer-v1.zip"

alert_notification_channels = []
