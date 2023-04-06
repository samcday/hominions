terraform {
  backend "kubernetes" {
    secret_suffix = "tfstate"
    namespace     = "kube-system"
  }
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.37.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.19.0"
    }
    oci = {
      source  = "oracle/oci"
      version = "4.115.0"
    }
  }
}

provider "hcloud" {}
provider "kubernetes" {}
provider "oci" {}

variable "ts_auth_key" {
  sensitive = true
  type      = string
}

locals {
  cloud_init = <<-HERE
  #!/bin/bash
  set -uexo pipefail
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

  oci_cloud_init = <<-HERE
  ${cloud_init}
  iptables -F
  netfilter-persistent save
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

resource "oci_core_instance" "node1" {
  availability_domain = "llxi:EU-FRANKFURT-1-AD-2"
  compartment_id      = "ocid1.tenancy.oc1..aaaaaaaag5t7yqzzm4fm33fcubvxkdeft3kyghnemjrpwmahkgnezhfm6oda"
  create_vnic_details {
    assign_public_ip = "true"
    display_name     = "oci-1"
    hostname_label   = "oci-1"
    subnet_id        = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaai2wks3esgitptrbhvngqhlz7rlojirh76zrchqaruupqxcekr2aq"
  }
  display_name = "oci-1"
  fault_domain = "FAULT-DOMAIN-1"

  metadata = {
    "ssh_authorized_keys" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFwawprQXEkGl38Q7T0PNseL0vpoyr4TbATMkEaZJTWQ"
    "user_data"           = base64encode(local.oci_cloud_init)
  }
  shape = "VM.Standard.A1.Flex"
  shape_config {
    memory_in_gbs = "12"
    ocpus         = "2"
  }
  source_details {
    boot_volume_vpus_per_gb = "10"
    source_id               = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaarvmmb4prjjytb2zc2fmxmgqcnzttj3g2kegcwzcd7fmroypj5fua"
    source_type             = "image"
  }
}


resource "oci_core_instance" "node2" {
  availability_domain = "llxi:EU-FRANKFURT-1-AD-1"
  compartment_id      = "ocid1.tenancy.oc1..aaaaaaaag5t7yqzzm4fm33fcubvxkdeft3kyghnemjrpwmahkgnezhfm6oda"
  create_vnic_details {
    assign_public_ip = "true"
    display_name     = "oci-2"
    hostname_label   = "oci-2"
    subnet_id        = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaai2wks3esgitptrbhvngqhlz7rlojirh76zrchqaruupqxcekr2aq"
  }
  display_name = "oci-2"
  fault_domain = "FAULT-DOMAIN-1"

  metadata = {
    "ssh_authorized_keys" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFwawprQXEkGl38Q7T0PNseL0vpoyr4TbATMkEaZJTWQ"
    "user_data"           = base64encode(local.oci_cloud_init)
  }
  shape = "VM.Standard.A1.Flex"
  shape_config {
    memory_in_gbs = "12"
    ocpus         = "2"
  }
  source_details {
    boot_volume_vpus_per_gb = "10"
    source_id               = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaarvmmb4prjjytb2zc2fmxmgqcnzttj3g2kegcwzcd7fmroypj5fua"
    source_type             = "image"
  }
}
