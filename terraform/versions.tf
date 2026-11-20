terraform {
  required_version = ">= 1.5"

  required_providers {
    # Pinned to the 0.8.x schema. The 0.9 series is a rewrite with a different
    # resource layout, so do not bump this without adapting main.tf.
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}
