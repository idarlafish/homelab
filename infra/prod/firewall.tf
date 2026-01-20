resource "hcloud_firewall" "common" {
  name = "tools-common-firewall"
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
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "7844"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Cloudflare Tunnel QUIC"
  }
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "443"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Cloudflare QUIC fallback"
  }
}

resource "hcloud_firewall" "telegram" {
  name = "telegram-firewall"
  
  # Inbound Web (nginx Ingress)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "HTTP"
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "HTTPS"
  }

  # Inbout NodePort
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "30080"  # Your NodePort
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Bot NodePort"
  }
  
  # Outbound Internet
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "443"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Telegram API HTTPS"
  }
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "80"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "HTTP"
  }
  
  # Cluster internal (split protocols)
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s TCP"
  }
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s UDP"
  }
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"]
    description     = "K8s ICMP"
  }
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "PING"
  }
}


resource "hcloud_firewall" "vpn" {
  name = "vpn-firewall"
  
  # Inbound WireGuard
  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30000"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "wg-easy WireGuard VPN"
  }
  
  # Outbound rules (required for return traffic)
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound UDP"
  }
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound TCP"
  }
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow ICMP"
  }
}
