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

variable "enable_cluster" {
  description = "Whether to provision the K3s server + Flux. Set false to scale to zero compute (only firewalls remain in state)."
  type        = bool
  default     = false
}
