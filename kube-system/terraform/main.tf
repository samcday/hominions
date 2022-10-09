terraform {
  backend "kubernetes" {
    secret_suffix = "state"
    namespace     = "kube-system"
  }
  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "0.8.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.25.0"
    }
    fly = {
      source = "fly-apps/fly"
      version = "0.0.20"
    }
  }
}

provider "b2" {}

provider "fly" {}

provider "cloudflare" {}

resource "b2_bucket" "headscale-backups" {
  bucket_name = "samcday-headscale-backups"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "fly-io-headscale-backups" {
  key_name     = "fly-io"
  bucket_id    = b2_bucket.headscale-backups.bucket_id
  capabilities = ["listFiles", "readFiles", "writeFiles", "deleteFiles"]
}
