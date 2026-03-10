terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.52.0"
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
  token = var.hcloud_token
}
