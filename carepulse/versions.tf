terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Remote state per Common Application Requirements (GCS backend on GCP).
  # Bucket/prefix supplied at init time via -backend-config, not hardcoded.
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}
