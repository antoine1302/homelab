# Generates the Ansible inventory from Terraform's own data, so IPs and names
# are defined in exactly one place.
resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.ini.tftpl", {
    vms          = local.vms
    admin_user   = var.admin_user
    gitlab_fqdn  = local.gitlab_fqdn
    grafana_fqdn = local.grafana_fqdn
    network_cidr = var.network_cidr
  })

  depends_on = [libvirt_domain.vm]
}

output "gitlab_url" {
  value = "https://${local.gitlab_fqdn}"
}

output "grafana_url" {
  value = "https://${local.grafana_fqdn}"
}

output "vm_addresses" {
  value = { for name, vm in local.vms : name => vm.ip }
}

output "next_steps" {
  value = <<-EOT
    VMs are created. Now run:
      cd ../ansible && ansible-playbook site.yml
    Optional: make the host resolve *.${var.domain} and trust the CA (see README.md).
  EOT
}
