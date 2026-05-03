terraform {
  required_version = ">= 1.11.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.60.1"
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  backend "s3" {
    bucket                      = "fabler"
    key                         = "tools-staging/terraform.tfstate"
    region                      = "auto"
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

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare_api_token"]
}

provider "kubernetes" {
  host                   = module.cluster.kubeconfig_data.server
  cluster_ca_certificate = module.cluster.kubeconfig_data.ca
  client_certificate     = module.cluster.kubeconfig_data.cert
  client_key             = module.cluster.kubeconfig_data.key
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.kubeconfig_data.server
    cluster_ca_certificate = module.cluster.kubeconfig_data.ca
    client_certificate     = module.cluster.kubeconfig_data.cert
    client_key             = module.cluster.kubeconfig_data.key
  }
}
