resource "hcloud_firewall" "vpn" {
  name = "vpn-firewall"
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30000"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "wg-easy wire guard"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "wg-easy HTTP-01 challenges"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "wg-easy web UI"
  }
}