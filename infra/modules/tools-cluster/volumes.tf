resource "hcloud_volume" "booklore_books" {
  name     = "${var.name}-booklore-books"
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

resource "hcloud_volume" "gatus_data" {
  name     = "${var.name}-gatus-data"
  size     = 10
  location = var.location
}

resource "kubernetes_persistent_volume_v1" "gatus_data" {
  metadata {
    name = "pv-gatus-data"
  }
  spec {
    capacity                         = { storage = "${hcloud_volume.gatus_data.size}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "hcloud-volumes-encrypted"

    persistent_volume_source {
      csi {
        driver        = "csi.hetzner.cloud"
        volume_handle = hcloud_volume.gatus_data.id
        fs_type       = "ext4"
      }
    }

    claim_ref {
      namespace = "monitoring"
      name      = "gatus-data"
    }
  }
}

resource "hcloud_volume" "loki_data" {
  name     = "${var.name}-loki-data"
  size     = 10
  location = var.location
}

resource "kubernetes_persistent_volume_v1" "loki_data" {
  metadata {
    name = "pv-loki-data"
  }
  spec {
    capacity                         = { storage = "${hcloud_volume.loki_data.size}Gi" }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "hcloud-volumes-encrypted"

    persistent_volume_source {
      csi {
        driver        = "csi.hetzner.cloud"
        volume_handle = hcloud_volume.loki_data.id
        fs_type       = "ext4"
      }
    }

    claim_ref {
      namespace = "monitoring"
      name      = "storage-loki-0"
    }
  }
}
