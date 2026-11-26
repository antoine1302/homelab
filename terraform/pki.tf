# ---------------------------------------------------------------------------
# Private CA + certificate for GitLab (HTTPS).
# The CA cert is trusted on every VM and handed to the runner pods by Ansible.
# NOTE: private keys end up in the Terraform state. Fine for a homelab.
# ---------------------------------------------------------------------------

locals {
  pki_org = "HomeLab"
}

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 24 * 365 * 5
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name  = "HomeLab Root CA"
    organization = local.pki_org
  }
}

resource "local_file" "ca_cert" {
  filename = "${path.module}/../ansible/pki/ca.crt"
  content  = tls_self_signed_cert.ca.cert_pem
}

# -------------------------------------------------
# Gitlab certificates
# -------------------------------------------------

resource "tls_private_key" "gitlab" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "gitlab" {
  private_key_pem = tls_private_key.gitlab.private_key_pem
  dns_names       = [local.gitlab_fqdn]
  ip_addresses    = [local.vms["gitlab"].ip]

  subject {
    common_name  = local.gitlab_fqdn
    organization = local.pki_org
  }
}

resource "tls_locally_signed_cert" "gitlab" {
  cert_request_pem      = tls_cert_request.gitlab.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 24 * 365
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "local_file" "gitlab_cert" {
  filename = "${path.module}/../ansible/pki/gitlab.crt"
  content  = tls_locally_signed_cert.gitlab.cert_pem
}

resource "local_sensitive_file" "gitlab_key" {
  filename        = "${path.module}/../ansible/pki/gitlab.key"
  content         = tls_private_key.gitlab.private_key_pem
  file_permission = "0600"
}

# -------------------------------------------------
# Grafana certificates
# Certificate for Grafana (served by k3s' Traefik), signed by the same HomeLab CA.
# Reach it with: 192.168.100.11 grafana.lab.test in /etc/hosts on the laptop.
# -------------------------------------------------

resource "tls_private_key" "grafana" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "grafana" {
  private_key_pem = tls_private_key.grafana.private_key_pem
  dns_names       = [local.grafana_fqdn]
  ip_addresses    = [local.vms["k3s-server"].ip]

  subject {
    common_name  = local.grafana_fqdn
    organization = local.pki_org
  }
}

resource "tls_locally_signed_cert" "grafana" {
  cert_request_pem      = tls_cert_request.grafana.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 24 * 365
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "local_file" "grafana_cert" {
  filename = "${path.module}/../ansible/pki/grafana.crt"
  content  = tls_locally_signed_cert.grafana.cert_pem
}

resource "local_sensitive_file" "grafana_key" {
  filename        = "${path.module}/../ansible/pki/grafana.key"
  content         = tls_private_key.grafana.private_key_pem
  file_permission = "0600"
}