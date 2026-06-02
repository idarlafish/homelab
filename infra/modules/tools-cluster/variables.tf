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

variable "cluster_pod_cidr" {
  description = "Pod CIDR range. Default mirrors hcloud-k8s/kubernetes/hcloud module default; surfaced via cluster-vars ConfigMap for Flux postBuild substitution."
  type        = string
  default     = "10.0.128.0/17"
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
  description = "Cloudflare tunnel ingress routes (cluster-internal hostnames + service URLs). Optional path is a regex; matches before the catch-all 404."
  type = list(object({
    hostname = string
    service  = string
    path     = optional(string)
  }))
}

variable "manage_zone_primitives" {
  description = "Manage zone-level Cloudflare resources (DNSSEC, CAA) from this module call. Exactly one cluster must set this to true."
  type        = bool
  default     = false
}
