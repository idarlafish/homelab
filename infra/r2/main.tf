locals {
  account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  clusters   = ["tools", "tools-staging", "game-servers"]
}

resource "cloudflare_r2_bucket" "backup" {
  for_each = toset(local.clusters)

  account_id = local.account_id
  name       = "${each.key}-backups"
  location   = "EEUR"

  lifecycle {
    prevent_destroy = true
  }
}
