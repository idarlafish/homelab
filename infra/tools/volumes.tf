# Hetzner Volumes whose lifecycle is owned by Tofu (durability across cluster
# recreate). Hetzner has no Volume snapshot API, so dynamic CSI provisioning
# loses data on `tofu destroy` of the cluster — Tofu-owned static volumes are
# the only pattern that survives. Reference: hetznercloud/csi-driver#146.
resource "hcloud_volume" "booklore_books" {
  name     = "tools-booklore-books"
  size     = 10
  location = var.hcloud_location
  format   = "ext4"
}
