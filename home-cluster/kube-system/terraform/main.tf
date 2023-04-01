terraform {
  backend "kubernetes" {
    secret_suffix = "state"
    namespace     = "kube-system"
  }
  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "0.8.4"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.35.0"
    }
    fly = {
      source  = "fly-apps/fly"
      version = "0.0.21"
    }
    github = {
      source  = "integrations/github"
      version = "5.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.14.0"
    }
  }
}

provider "b2" {}

provider "cloudflare" {}

provider "fly" {}

provider "github" {}

provider "kubernetes" {}

# data "kubernetes_secret" "webhook-token" {
#   metadata {
#     name      = "webhook-token"
#     namespace = "flux-system"
#   }
# }

# data "kubernetes_resource" "receiver" {
#   api_version = "notification.toolkit.fluxcd.io/v1beta1"
#   kind        = "Receiver"

#   metadata {
#     name      = "home-cluster"
#     namespace = "flux-system"
#   }
# }

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

# resource "github_repository_webhook" "hominion-push" {
#   active = true
#   configuration {
#     content_type = "form"
#     insecure_ssl = false
#     secret       = base64decode(data.kubernetes_secret.webhook-token.data.token)

# this part sadly doesn't currently work
# maybe fixed soon? https://github.com/hashicorp/terraform-provider-kubernetes/pull/1802
# ironically linked issue ran into problem exact same way I did, trying to scoop url out of a Flux Receiver.... Welp.

#     url          = "https://home-flux.samcday.com${data.kubernetes_resource.receiver.object.status.url}"
#   }
#   events     = ["push"]
#   repository = "samcday/home-cluster"
# }

# if fly adds support for secrets
# https://github.com/fly-apps/terraform-provider-fly/issues/27
# can manage the headscale backup bucket credentials here
