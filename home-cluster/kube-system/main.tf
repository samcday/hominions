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
      version = "1.37.0"
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
  mkdir -p /etc/cni
  cat > /etc/cni/template <<TMPL
  {
    "name": "k8s-pod-network",
    "cniVersion": "0.3.1",
    "plugins": [
      {
        "type": "ptp",
        "mtu": 1460,
        "ipam": {
          "type": "host-local",
          "subnet": "{{.PodCIDR}}",
          "routes": [
            {
              "dst": "0.0.0.0/0"
            }
          ]
        }
      },
      {
        "type": "portmap",
        "capabilities": {
          "portMappings": true
        }
      }
    ]
  }
  TMPL
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt install -y containernetworking-plugins tailscale containerd.io

  containerd config default \
      | sed 's/bin_dir = .*/bin_dir = "\/usr\/lib\/cni"/g' \
      | sed 's/conf_template = ""/conf_template = "\/etc\/cni\/template"/' \
      > /etc/containerd/config.toml
  systemctl restart containerd

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
