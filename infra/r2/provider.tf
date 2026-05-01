terraform {
  required_version = ">= 1.11.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4"
    }
  }
  backend "s3" {
    bucket = "fabler"
    key    = "r2/terraform.tfstate"
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

provider "cloudflare" {
  api_token = data.sops_file.secrets.data["cloudflare_api_token"]
}
