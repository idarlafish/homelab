resource "hcloud_firewall" "k8s" {
  name = "${var.name}-k8s-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Kubernetes API"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "7844"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Cloudflare Tunnel QUIC"
  }
}

resource "hcloud_firewall" "web" {
  name = "${var.name}-web-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "30080"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Bot NodePort"
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s internal TCP"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s internal UDP"
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s internal ICMP"
  }
}

resource "hcloud_firewall" "vpn" {
  name = "${var.name}-vpn-firewall"

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30000"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "WireGuard VPN"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "VPN outbound UDP (all)"
  }
}
