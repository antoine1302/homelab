variable "libvirt_uri" {
  description = "libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "pool_path" {
  description = "Directory used for the lab storage pool (must be writable by libvirt/qemu)"
  type        = string
  default     = "/home/totoro/vmdisks"
}

variable "base_image_url" {
  description = "Ubuntu 26.04 LTS (resolute) cloud image"
  type        = string
  default     = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64v3.img"
}

variable "ssh_public_key_path" {
  description = "Public key injected into the VMs for the admin user"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "admin_user" {
  type    = string
  default = "ubuntu"
}

variable "network_cidr" {
  description = "NAT network used by the lab"
  type        = string
  default     = "192.168.100.0/24"
}

variable "domain" {
  description = "DNS domain of the lab network (.test is reserved and never resolves publicly)"
  type        = string
  default     = "homelab.test"
}

variable "gitlab_vcpus" {
  type    = number
  default = 4
}

variable "gitlab_memory_mb" {
  type    = number
  default = 8192
}

variable "gitlab_disk_gb" {
  type    = number
  default = 60
}

variable "k3s_vcpus" {
  type    = number
  default = 2
}

variable "k3s_memory_mb" {
  type    = number
  default = 4096
}

variable "k3s_disk_gb" {
  type    = number
  default = 30
}
