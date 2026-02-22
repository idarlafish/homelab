variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type (e.g. cax11, cax21)"
  type        = string
  default     = "cax11"
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "hel1"
}

variable "ssh_key_id" {
  description = "ID of the Hetzner uploaded SSH key"
  type        = string
}

variable "private_ip" {
  description = "Static private IP for the server within the private network"
  type        = string
}

variable "extra_firewall_ids" {
  description = "Additional environment-specific firewall IDs to attach"
  type        = list(string)
  default     = []
}

variable "cloud_init" {
  description = "Cloud-init user_data string"
  type        = string
}

variable "network_ip_range" {
  description = "IP range for the private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ip_range" {
  description = "IP range for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}
