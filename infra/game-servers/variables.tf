variable "hcloud_token" {
  description = "Hetzner API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Hetzner uploaded SSH key name for provisioning"
  type        = string
}

variable "hcloud_location" {
  description = "Hetzner location (e.g. fsn1, nbg1, hel1)"
  type        = string
  default     = "fsn1"
}

variable "github_token" {
  description = "GitHub PAT with repo:read on idarlafish/tools (used by Flux source-controller for GitRepository sync)"
  type        = string
  sensitive   = true
}

variable "sops_age_key" {
  description = "Age private key for SOPS decryption inside the cluster"
  type        = string
  sensitive   = true
}

variable "bootstrap_revision" {
  description = "Bump to force the flux-operator bootstrap Job to re-run"
  type        = number
  default     = 1
}
