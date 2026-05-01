locals {
  account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  clusters   = ["tools", "tools-staging", "game-servers"]

  # Retention applies to tools + tools-staging only; game-servers backups
  # are precious world saves with no auto-expire.
  retention_clusters = ["tools", "tools-staging"]
  retention_apps     = ["booklore", "pocket-id"]
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

resource "cloudflare_r2_bucket_lifecycle" "backup" {
  for_each = toset(local.retention_clusters)

  account_id  = local.account_id
  bucket_name = cloudflare_r2_bucket.backup[each.key].name

  rules = flatten([
    for app in local.retention_apps : [
      {
        id         = "${app}-daily-7d"
        enabled    = true
        conditions = { prefix = "${app}/daily/" }
        delete_objects_transition = {
          condition = {
            type    = "Age"
            max_age = 7 * 86400
          }
        }
      },
      {
        id         = "${app}-weekly-28d"
        enabled    = true
        conditions = { prefix = "${app}/weekly/" }
        delete_objects_transition = {
          condition = {
            type    = "Age"
            max_age = 28 * 86400
          }
        }
      },
    ]
  ])
}
