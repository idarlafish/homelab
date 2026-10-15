resource "hcloud_volume" "enshrouded_data" {
  name     = "game-servers-enshrouded-data"
  size     = 10
  location = var.hcloud_location
}

# Retain: a CSI-dynamic claim took the world down with the 2026-09 teardown.
resource "kubernetes_persistent_volume_v1" "enshrouded_data" {
  metadata {
    name = "pv-enshrouded-data"
  }
  spec {
    capacity                         = { storage = "${hcloud_volume.enshrouded_data.size}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "hcloud-volumes"

    persistent_volume_source {
      csi {
        driver        = "csi.hetzner.cloud"
        volume_handle = hcloud_volume.enshrouded_data.id
        fs_type       = "ext4"
      }
    }

    # StatefulSet volumeClaimTemplate name: <template>-<sts>-<ordinal>.
    claim_ref {
      namespace = "enshrouded"
      name      = "enshrouded-data-enshrouded-0"
    }
  }
}
