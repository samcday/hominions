terraform {
  backend "kubernetes" {
    secret_suffix = "state"
    namespace     = "kube-system"
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.19.0"
    }
  }
}

provider "cloudflare" {}

provider "kubernetes" {}

resource "b2_bucket" "headscale-backups" {
  bucket_name = "samcday-headscale-backups"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "fly-io-headscale-backups" {
  key_name     = "fly-io"
  bucket_id    = b2_bucket.headscale-backups.bucket_id
  capabilities = ["listFiles", "readFiles", "writeFiles", "deleteFiles"]
}
