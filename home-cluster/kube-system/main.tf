terraform {
  backend "kubernetes" {
    secret_suffix = "tfstate"
    namespace     = "kube-system"
  }
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.19.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.36.2"
    }
  }
}

provider "kubernetes" {}

provider "hcloud" {}

variable "ts_auth_key" {
  sensitive = true
  type      = string
}

locals {
  cloud_init = <<-HERE
  #!/bin/sh
  hostnamectl hostname $(hostname -f)
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt install -y containernetworking-plugins tailscale
  rm -rf /opt/cni/bin
  ln /usr/lib/cni -s /opt/cni/bin
  tailscale up --login-server=https://samcday-headscale.fly.dev --authkey=${var.ts_auth_key} --accept-routes --accept-dns
  HERE
}

resource "hcloud_ssh_key" "me" {
  name       = "me"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFwawprQXEkGl38Q7T0PNseL0vpoyr4TbATMkEaZJTWQ"
}

resource "hcloud_placement_group" "pg" {
  name = "hominions"
  type = "spread"
}

resource "hcloud_server" "node1" {
  name               = "hc-1.hominions.tailnet.samcday.com"
  image              = "ubuntu-22.04"
  server_type        = "cx31"
  location           = "fsn1"
  placement_group_id = hcloud_placement_group.pg.id
  ssh_keys           = ["me"]
  user_data          = local.cloud_init
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}

resource "hcloud_server" "node2" {
  name               = "hc-2.hominions.tailnet.samcday.com"
  image              = "ubuntu-22.04"
  server_type        = "cx31"
  location           = "fsn1"
  placement_group_id = hcloud_placement_group.pg.id
  ssh_keys           = ["me"]
  user_data          = local.cloud_init
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
