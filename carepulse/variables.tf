variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "application" {
  type    = string
  default = "carepulse"
}

variable "environment" {
  description = "production / staging / dev"
  type        = string
}

variable "data_class" {
  description = "phi / pii / internal / public"
  type        = string
  default     = "phi"
}

variable "vpc_connector_id" {
  description = "Fully qualified Serverless VPC Access connector ID in the platform's custom VPC. Not created here — provided by Platform Engineering."
  type        = string
}

variable "kms_key_ring_id" {
  description = "Existing KMS key ring to hold this app's CMEK key."
  type        = string
}

variable "alert_notification_channels" {
  description = "Monitoring notification channel IDs (on-call, Slack, etc)."
  type        = list(string)
  default     = []
}

variable "ingest_image" {
  description = "Container image for the vitals ingest service."
  type        = string
}
