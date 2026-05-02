resource "hcloud_volume" "booklore_books" {
  name     = "${var.name}-booklore-books"
  size     = 10
  location = var.location
}

resource "hcloud_volume" "pocket_id_data" {
  name     = "${var.name}-pocket-id-data"
  size     = 10
  location = var.location
}

resource "kubernetes_persistent_volume_v1" "booklore_books" {
  metadata {
    name = "pv-booklore-books"
  }
  spec {
    capacity                         = { storage = "${hcloud_volume.booklore_books.size}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "hcloud-volumes-encrypted"

    persistent_volume_source {
      csi {
        driver        = "csi.hetzner.cloud"
        volume_handle = hcloud_volume.booklore_books.id
        fs_type       = "ext4"
      }
    }

    claim_ref {
      namespace = "booklore"
      name      = "booklore-books"
    }
  }
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

resource "hcloud_volume" "paperless_storage" {
  name     = "${var.name}-paperless-storage"
  size     = 10
  location = var.location
}

resource "kubernetes_persistent_volume_v1" "paperless_storage" {
  metadata {
    name = "pv-paperless-storage"
  }
  spec {
    capacity                         = { storage = "${hcloud_volume.paperless_storage.size}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "hcloud-volumes-encrypted"

    persistent_volume_source {
      csi {
        driver        = "csi.hetzner.cloud"
        volume_handle = hcloud_volume.paperless_storage.id
        fs_type       = "ext4"
      }
    }

    claim_ref {
      namespace = "paperless"
      name      = "paperless-storage"
    }
  }
}
