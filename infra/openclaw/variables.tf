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
  description = "Hetzner location"
  type        = string
  default     = "hel1"
}
