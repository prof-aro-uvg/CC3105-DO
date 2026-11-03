terraform {
  required_version = ">= 1.3"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# The provider lives in the root module only; the child module inherits it.
provider "digitalocean" {
  token = var.do_token
}
