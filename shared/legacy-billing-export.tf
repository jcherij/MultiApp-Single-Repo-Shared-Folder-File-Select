# Leftover from the decommissioned billing-export pilot (Q1 2026). Not wired
# into carepulse or chartvault. Left here pending cleanup — do not treat this
# as an active third app.
resource "google_bigquery_dataset" "billing_export_pilot" {
  dataset_id  = "billing_export_pilot"
  location    = "US"
  description = "Deprecated — scheduled for removal, see JIRA PLAT-4021"
}
