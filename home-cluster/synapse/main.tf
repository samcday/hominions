terraform {
  backend "kubernetes" {
    secret_suffix = "state"
    namespace     = "synapse"
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

resource "b2_bucket" "synapse-backups" {
  bucket_name = "samcday-synapse-backups"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "synapse-backups" {
  key_name     = "synapse"
  bucket_id    = b2_bucket.synapse-backups.bucket_id
  capabilities = ["listFiles", "readFiles", "writeFiles", "deleteFiles"]
}

resource "kubernetes_secret" "synapse-backup-bucket" {
  metadata {
    name      = "backup-bucket"
    namespace = "synapse"
  }

  data = {
    LITESTREAM_ACCESS_KEY_ID     = b2_application_key.synapse-backups.application_key_id
    LITESTREAM_SECRET_ACCESS_KEY = b2_application_key.synapse-backups.application_key
  }
}
