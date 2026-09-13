project_id  = "kennari-medtest-prod"
region      = "us-central1"
environment = "production"
data_class  = "phi"

vpc_connector_id = "projects/kennari-medtest-prod/locations/us-central1/connectors/platform-vpc-connector"
kms_key_ring_id  = "projects/kennari-medtest-prod/locations/us-central1/keyRings/app-keys"
ingest_image     = "us-central1-docker.pkg.dev/kennari-medtest-prod/carepulse/ingest:latest"

alert_notification_channels = [
  "projects/kennari-medtest-prod/notificationChannels/1234567890"
]
