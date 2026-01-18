resource "hcloud_firewall" "common" {
  name = "common-firewall"
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Kubernetes"
  }
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow SSH from my IP"
  }
  rule {
    description = "Allow PING"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = [
      "0.0.0.0/0"
    ]
  }
}

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