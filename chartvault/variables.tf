variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "application" {
  type    = string
  default = "chartvault"
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

variable "kms_key_ring_id" {
  description = "Existing KMS key ring to hold this app's CMEK key."
  type        = string
}

variable "retention_seconds" {
  description = "HIPAA minimum for PHI is 6 years (189,216,000s). Do not lower without a documented exception."
  type        = number
  default     = 189216000
}

variable "writer_source_bucket" {
  description = "GCS bucket holding the zipped source for the archive-writer Cloud Function."
  type        = string
}

variable "writer_source_object" {
  type = string
}

variable "alert_notification_channels" {
  type    = list(string)
  default = []
}
