terraform {
  required_version = ">= 1.11.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.52.0"
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
    bucket = "fabler"
    key    = "tools/terraform.tfstate"
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

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare_api_token"]
}

provider "kubernetes" {
  host                   = module.server.kube_endpoint
  cluster_ca_certificate = base64decode(module.server.kube_ca_certificate)
  client_certificate     = base64decode(module.server.kube_client_certificate)
  client_key             = base64decode(module.server.kube_client_key)
}

provider "helm" {
  kubernetes = {
    host                   = module.server.kube_endpoint
    cluster_ca_certificate = base64decode(module.server.kube_ca_certificate)
    client_certificate     = base64decode(module.server.kube_client_certificate)
    client_key             = base64decode(module.server.kube_client_key)
  }
}
