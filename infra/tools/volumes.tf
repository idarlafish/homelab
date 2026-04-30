resource "hcloud_volume" "booklore_books" {
  name     = "tools-booklore-books"
  size     = 10
  location = var.hcloud_location
  format   = "ext4"
}

resource "hcloud_volume" "pocket_id_data" {
  name     = "tools-pocket-id-data"
  size     = 10
  location = var.hcloud_location
  format   = "ext4"
}
