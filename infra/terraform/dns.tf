# ---------------------------------------------------------------------------
# Certificados TLS
#
# El DNS del dominio vive en Hostinger, no en Route 53, así que la validación no puede
# automatizarse: Terraform emite el certificado y expone los registros CNAME que hay que
# crear a mano en el panel de Hostinger. Hasta que se creen, `terraform apply` se queda
# esperando la validación.
#
# Route 53 permitiría automatizarlo, pero cobra 0,50 USD al mes por zona alojada sin aportar
# nada más en este escenario.
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "principal" {
  count = var.usar_dominio_propio ? 1 : 0

  domain_name = "${var.subdominio_web}.${var.dominio}"
  subject_alternative_names = ["${var.subdominio_api}.${var.dominio}"]
  validation_method         = "DNS"

  lifecycle {
    # Emite el reemplazo antes de retirar el anterior, para no dejar el sitio sin certificado
    # durante una renovación.
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "principal" {
  count = var.usar_dominio_propio ? 1 : 0

  certificate_arn = aws_acm_certificate.principal[0].arn

  timeouts {
    # Margen para crear los registros a mano y para que se propaguen.
    create = "60m"
  }
}
