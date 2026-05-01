variable "hcloud_location" {
  description = "Hetzner location (e.g. fsn1, nbg1, hel1)"
  type        = string
  default     = "fsn1"
}

variable "sops_age_key" {
  description = "Age private key for SOPS decryption inside the cluster (bootstrap-only secret; everything else lives in infra/secrets.sops.yaml)"
  type        = string
  sensitive   = true
}

variable "bootstrap_revision" {
  description = "Bump to force the flux-operator bootstrap Job to re-run"
  type        = number
  default     = 1
}
