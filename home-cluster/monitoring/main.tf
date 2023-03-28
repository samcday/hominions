terraform {
  backend "kubernetes" {
    secret_suffix = "state"
    namespace     = "monitoring"
  }
  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "0.8.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.14.0"
    }
  }
}

provider "b2" {}
provider "kubernetes" {}


resource "b2_bucket" "grafana-backups" {
  bucket_name = "samcday-grafana-backups"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "grafana-backups" {
  key_name     = "grafana"
  bucket_id    = b2_bucket.grafana-backups.bucket_id
  capabilities = ["listFiles", "readFiles", "writeFiles", "deleteFiles"]
}

resource "kubernetes_secret" "grafana-backups-bucket" {
  metadata {
    name      = "grafana-backups-bucket"
    namespace = "monitoring"
  }

  data = {
    LITESTREAM_ACCESS_KEY_ID     = b2_application_key.grafana-backups.application_key_id
    LITESTREAM_SECRET_ACCESS_KEY = b2_application_key.grafana-backups.application_key
  }
}
