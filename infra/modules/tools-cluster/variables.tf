variable "name" {
  description = "Cluster name (used as resource prefix; also tunnel name)"
  type        = string
}

variable "server_type" {
  type    = string
  default = "cax11"
}

variable "location" {
  type    = string
  default = "hel1"
}

variable "private_ip" {
  type = string
}

variable "network_ip_range" {
  type = string
}

variable "subnet_ip_range" {
  type = string
}

variable "ssh_key_id" {
  description = "Hetzner SSH key resource id"
  type        = string
}

variable "ssh_private_key" {
  type      = string
  sensitive = true
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "github_token" {
  description = "GitHub PAT for Flux source-controller"
  type        = string
  sensitive   = true
}

variable "sops_age_key" {
  type      = string
  sensitive = true
}

variable "bootstrap_revision" {
  type    = number
  default = 1
}

variable "manage_flux_bootstrap" {
  description = "Install flux-operator via flux-operator-bootstrap chart. Set to false on clusters where flux-operator was installed by other means."
  type        = bool
  default     = true
}

variable "flux_instance_yaml" {
  description = "Rendered FluxInstance YAML"
  type        = string
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_name" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "tunnel_routes" {
  description = "Cloudflare tunnel ingress routes (cluster-internal hostnames + service URLs)"
  type = list(object({
    hostname = string
    service  = string
  }))
}

variable "tunnel_dns_subdomains" {
  description = "Subdomain prefixes (sans zone) to create CNAME records for, pointing at the tunnel"
  type        = list(string)
}
