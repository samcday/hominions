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

resource "b2_bucket" "hominion-cluster-backups" {
  bucket_name = "samcday-hominion-cluster-backups"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "hominion-cluster-backups" {
  key_name     = "kube-system-cluster-backups-bucket"
  bucket_id    = b2_bucket.hominion-cluster-backups.bucket_id
  capabilities = ["listAllBucketNames", "listBuckets", "listFiles", "readFiles", "writeFiles", "deleteFiles"]
}

resource "kubernetes_secret" "kube-system-cluster-backups-bucket" {
  metadata {
    name      = "cluster-backups-bucket"
    namespace = "kube-system"
  }

  data = {
    "config.yaml" = yamlencode({
      etcd-s3-access-key = b2_application_key.hominion-cluster-backups.application_key_id
      etcd-s3-secret-key = b2_application_key.hominion-cluster-backups.application_key
    })
  }
}
