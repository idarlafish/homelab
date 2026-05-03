resource "hcloud_volume" "pocket_id_data" {
  name     = "tools-pocket-id-data"
  size     = 10
  location = var.hcloud_location
}

resource "kubernetes_persistent_volume_v1" "pocket_id_data" {
  metadata {
    name = "pv-pocket-id-data"
  }
  spec {
    capacity                         = { storage = "${hcloud_volume.pocket_id_data.size}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "hcloud-volumes-encrypted"

    persistent_volume_source {
      csi {
        driver        = "csi.hetzner.cloud"
        volume_handle = hcloud_volume.pocket_id_data.id
        fs_type       = "ext4"
      }
    }

    claim_ref {
      namespace = "identity"
      name      = "pocket-id-data"
    }
  }
}

resource "hcloud_volume" "vaultwarden_data" {
  name     = "tools-vaultwarden-data"
  size     = 10
  location = var.hcloud_location
}

resource "kubernetes_persistent_volume_v1" "vaultwarden_data" {
  metadata {
    name = "pv-vaultwarden-data"
  }
  spec {
    capacity                         = { storage = "${hcloud_volume.vaultwarden_data.size}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "hcloud-volumes-encrypted"

    persistent_volume_source {
      csi {
        driver        = "csi.hetzner.cloud"
        volume_handle = hcloud_volume.vaultwarden_data.id
        fs_type       = "ext4"
      }
    }

    claim_ref {
      namespace = "vault"
      name      = "vaultwarden-data"
    }
  }
}
