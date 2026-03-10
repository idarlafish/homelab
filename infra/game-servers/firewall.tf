resource "hcloud_firewall" "k8s" {
  name = "game-servers-k8s-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Kubernetes API"
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
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound UDP"
  }
}

resource "hcloud_firewall" "servers" {
  name = "game-servers-firewall"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "7777"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Satisfactory: Game server TCP (API)"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "7777"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Satisfactory: Game server UDP (Game)"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "18888"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Satisfactory: Game server TCP (Messaging)"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30821"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Palworld: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30921"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Palworld: Game server Query NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30637"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Enshrouded: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30456"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Valheim: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30457"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Valheim: Game server Query NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30458"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Valheim: Game server Second NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30565"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Minecraft: Game server UDP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "30565"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Minecraft: Game server TCP"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30724"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Foundry: Game server NodePort"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "30668"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Core Keeper: Game server NodePort"
  }
}
