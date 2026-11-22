locals {
  vms = {
    "gitlab" = {
      ip        = cidrhost(var.network_cidr, 10)
      fqdn      = "gitlab.${var.domain}"
      vcpus     = var.gitlab_vcpus
      memory_mb = var.gitlab_memory_mb
      disk_gb   = var.gitlab_disk_gb
    }

    "k3s-server" = {
      ip        = cidrhost(var.network_cidr, 11)
      fqdn      = "k3s-server.${var.domain}"
      vcpus     = var.k3s_vcpus
      memory_mb = var.k3s_memory_mb
      disk_gb   = var.k3s_disk_gb
    }

    "k3s-agent-01" = {
      ip        = cidrhost(var.network_cidr, 12)
      fqdn      = "k3s-agent-01.${var.domain}"
      vcpus     = var.k3s_vcpus
      memory_mb = var.k3s_memory_mb
      disk_gb   = var.k3s_disk_gb
    }

    "k3s-agent-02" = {
      ip        = cidrhost(var.network_cidr, 12)
      fqdn      = "k3s-agent-02.${var.domain}"
      vcpus     = var.k3s_vcpus
      memory_mb = var.k3s_memory_mb
      disk_gb   = var.k3s_disk_gb
    }
  }

  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

# ---------------------------------------------------------------------------
# Network: NAT, no DHCP (static IPs via cloud-init), dnsmasq answers for the
# homelab names so gitlab.homelab.test resolves on the VMs and inside the k3s pods.
# ---------------------------------------------------------------------------
resource "libvirt_network" "homelab" {
  name      = "homelab"
  autostart = true

  ips = [
    { address = cidrhost(var.network_cidr, 0), netmask = cidrnetmask(var.network_cidr) }
  ]

  forward = {
    mode = "nat"
    nat = {
      ports = [{ start = 1024, end = 65535 }]
    }
  }

  bridge = {
    name  = "virbr-homelab"
    stp   = "on"
    delay = "0"
  }

  dns = {
    enable = "yes"
    host = [for name, vm in local.vms : {
      ip        = vm.ip
      hostnames = [{ hostname = vm.fqdn }]
    }]
  }

  domain = {
    name       = var.domain
    local_only = "yes"
  }
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------
resource "libvirt_pool" "homelab" {
  name = "homelab"
  type = "dir"
  target = {
    path = var.pool_path
    permissions = {
      mode  = "0755"
      owner = "1000"
      group = "984"
    }
  }
}

resource "libvirt_volume" "base" {
  name = "ubuntu-2604-base.qcow2"
  pool = libvirt_pool.homelab.name
  target = {
    format = {
      type = "qcow2"
    }
  }
  create = {
    content = {
      url = var.base_image_url
    }
  }
}

resource "libvirt_volume" "disk" {
  for_each = local.vms

  name     = "${each.key}.qcow2"
  pool     = libvirt_pool.homelab.name
  capacity = each.value.disk_gb * 1024 * 1024 * 1024

  target = {
    format = { type = "qcow2" }
  }

  backing_store = {
    path   = libvirt_volume.base.path
    format = { type = "qcow2" }
  }
}

# ---------------------------------------------------------------------------
# cloud-init: user, SSH key, static network, guest agent. Everything else is
# done by Ansible.
# ---------------------------------------------------------------------------
resource "libvirt_cloudinit_disk" "init" {
  for_each = local.vms

  name = "${each.key}-cloudinit"

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
    hostname   = each.key
    fqdn       = each.value.fqdn
    admin_user = var.admin_user
    ssh_key    = local.ssh_public_key
  })

  meta_data = templatefile("${path.module}/cloud-init/meta-data.yaml.tftpl", {})

  network_config = templatefile("${path.module}/cloud-init/network-data.yaml.tftpl", {})
}

# Upload each ISO into the pool
resource "libvirt_volume" "seed" {
  for_each = local.vms

  name = "${each.key}-cloudinit.iso"
  pool = libvirt_pool.homelab.name

  target = {
    format = { type = "raw" }
  }

  create = {
    content = { url = libvirt_cloudinit_disk.init[each.key].path }
  }
}

# ---------------------------------------------------------------------------
# Virtual machines
# ---------------------------------------------------------------------------
resource "libvirt_domain" "vm" {
  for_each = local.vms

  name        = each.key
  type        = "kvm"
  memory      = each.value.memory_mb
  memory_unit = "MiB"
  vcpu        = each.value.vcpus
  running     = true
  autostart   = false

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  features = { acpi = true }

  cpu = { mode = "host-passthrough" }

  devices = {
    disks = [
      {
        device = "disk"

        driver = { name = "qemu", type = "qcow2" }

        source = {
          volume = {
            pool   = libvirt_pool.homelab.name
            volume = libvirt_volume.disk[each.key].name
          }
        }

        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"

        driver = {
          name = "qemu"
          type = "raw"
        }

        source = {
          volume = {
            pool   = libvirt_pool.homelab.name
            volume = libvirt_volume.seed[each.key].name
          }
        }

        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    interfaces = [{
      source = { network = { network = libvirt_network.homelab.name } }
      model  = { type = "virtio" }
    }]

    consoles = [{
      target = { type = "serial", port = 0 }
    }]

    graphics = [{
      spice = {
        auto_port = true
        listen    = "127.0.0.1"
      }
    }]
  }
}