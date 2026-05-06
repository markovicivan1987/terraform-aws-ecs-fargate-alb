resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  private_key_pem = tls_private_key.self_signed.private_key_pem

  subject {
    common_name  = "${var.app_name}.local"
    organization = var.app_name
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "time_sleep" "wait_for_cert" {
  depends_on      = [tls_self_signed_cert.self_signed]
  create_duration = "60s"
}

resource "aws_acm_certificate" "self_signed" {
  depends_on       = [time_sleep.wait_for_cert]
  private_key      = tls_private_key.self_signed.private_key_pem
  certificate_body = tls_self_signed_cert.self_signed.cert_pem

  tags = {
    Name = "${var.app_name}-cert"
  }
}
