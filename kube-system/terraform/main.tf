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
    dmsnitch = {
      source  = "plukevdh/dmsnitch"
      version = "0.1.4"
    }
    fly = {
      source  = "fly-apps/fly"
      version = "0.0.20"
    }
    github = {
      source  = "integrations/github"
      version = "5.5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.14.0"
    }
  }
}

provider "b2" {}

provider "cloudflare" {}

provider "dmsnitch" {}

provider "fly" {}

provider "github" {}

provider "kubernetes" {}

data "kubernetes_secret" "webhook-token" {
  metadata {
    name      = "webhook-token"
    namespace = "flux-system"
  }
}

data "kubernetes_resource" "receiver" {
  api_version = "notification.toolkit.fluxcd.io/v1beta1"
  kind        = "Receiver"

  metadata {
    name      = "home-cluster"
    namespace = "flux-system"
  }
}

resource "dmsnitch_snitch" "hominion" {
  name = "Hominion"

  interval = "hourly"
  type     = "basic"
}

resource "kubernetes_secret" "monitoring-dms-url" {
  metadata {
    name      = "dms-url"
    namespace = "monitoring"
  }

  data = {
    "url" = dmsnitch_snitch.hominion.url
  }
}

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

resource "b2_bucket" "grafana-backups" {
  bucket_name = "samcday-grafana-backups"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "grafana-backups" {
  key_name     = "grafana"
  bucket_id    = b2_bucket.grafana-backups.bucket_id
  capabilities = ["listFiles", "readFiles", "writeFiles", "deleteFiles"]
}

resource "kubernetes_secret" "monitoring-grafana-backup-bucket" {
  metadata {
    name      = "grafana-backup-bucket"
    namespace = "monitoring"
  }

  data = {
    LITESTREAM_ACCESS_KEY_ID     = b2_application_key.grafana-backups.application_key_id
    LITESTREAM_SECRET_ACCESS_KEY = b2_application_key.grafana-backups.application_key
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

#     url          = "https://flux.home.samcday.com${data.kubernetes_resource.receiver.object.status.url}"
#   }
#   events     = ["push"]
#   repository = "samcday/home-cluster"
# }

# if fly adds support for secrets
# https://github.com/fly-apps/terraform-provider-fly/issues/27
# can manage the headscale backup bucket credentials here
