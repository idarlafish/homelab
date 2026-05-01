terraform {
  required_version = ">= 1.11.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.60.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4"
    }
  }
  backend "s3" {
    bucket = "fabler"
    key    = "game-servers/terraform.tfstate"
    region = "auto"
    endpoints = {
      s3 = "https://95c5c6e1c01ea2d0c9fab69ee9e28462.r2.cloudflarestorage.com"
    }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "hcloud" {
  token = data.sops_file.secrets.data["hcloud_token"]
}

provider "kubernetes" {
  host                   = module.talos.kubeconfig_data.server
  cluster_ca_certificate = module.talos.kubeconfig_data.ca
  client_certificate     = module.talos.kubeconfig_data.cert
  client_key             = module.talos.kubeconfig_data.key
}

provider "helm" {
  kubernetes = {
    host                   = module.talos.kubeconfig_data.server
    cluster_ca_certificate = module.talos.kubeconfig_data.ca
    client_certificate     = module.talos.kubeconfig_data.cert
    client_key             = module.talos.kubeconfig_data.key
  }
}
