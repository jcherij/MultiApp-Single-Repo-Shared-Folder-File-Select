# Test setup

This repo exists to test how Kennari.ai behaves when a user manually selects
files out of a shared, cluttered folder rather than the engine auto-scanning
a whole repo.

## Layout

- `carepulse/` — Terraform for the carepulse app (patient vitals intake, GCP).
- `chartvault/` — Terraform for the chartvault app (patient chart archive, GCP).
- `shared/` — a mixed folder, on purpose:
  - `carepulse.tfvars`, `carepulse-nonprod.tfvars` — belong to carepulse.
  - `chartvault.tfvars`, `chartvault-nonprod.tfvars` — belong to chartvault.
  - `org-tagging-reference.md`, `legacy-billing-export.tf` — belong to
    neither app. They're clutter a real shared folder accumulates over time.
  - `some_folder/` — more unrelated clutter (on-call notes), included to
    check that Kennari.ai doesn't pull in a whole subfolder just because it
    sits next to something relevant.
  - `readme_folder/` — this file.

## What the test checks

When a user selects, say, only `carepulse/*.tf` plus
`shared/carepulse.tfvars`, Kennari.ai's findings and generated intent should
show no awareness of `chartvault.tfvars`, the nonprod files, or anything
under `some_folder/`. Any finding that references values or resources from
an unselected file is a scope leak, not a real finding.
