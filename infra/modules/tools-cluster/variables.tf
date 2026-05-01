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

variable "cluster_delete_protection" {
  description = "Enable Hetzner delete protection on cluster resources. Flip to false (and apply) right before running tofu destroy."
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
