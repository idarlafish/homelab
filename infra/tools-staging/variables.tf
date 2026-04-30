variable "hcloud_location" {
  description = "Hetzner location"
  type        = string
  default     = "hel1"
}

variable "sops_age_key" {
  description = "Age private key for SOPS decryption inside the cluster (bootstrap-only secret)"
  type        = string
  sensitive   = true
}

variable "bootstrap_revision" {
  description = "Bump to force the flux-operator bootstrap Job to re-run"
  type        = number
  default     = 1
}
