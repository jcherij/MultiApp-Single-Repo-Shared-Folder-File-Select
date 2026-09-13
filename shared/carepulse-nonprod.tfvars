project_id  = "kennari-medtest-nonprod"
region      = "us-central1"
environment = "staging"
data_class  = "phi"

vpc_connector_id = "projects/kennari-medtest-nonprod/locations/us-central1/connectors/platform-vpc-connector"
kms_key_ring_id  = "projects/kennari-medtest-nonprod/locations/us-central1/keyRings/app-keys"
ingest_image     = "us-central1-docker.pkg.dev/kennari-medtest-nonprod/carepulse/ingest:latest"

alert_notification_channels = []
