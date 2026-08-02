output "url_api" {
  description = "URL de la API. Es la que asigna AWS mientras el dominio propio no esté activo."
  value       = aws_lambda_function_url.api.function_url
}

output "nombre_funcion" {
  description = "Nombre de la función Lambda."
  value       = aws_lambda_function.api.function_name
}

output "version_publicada" {
  description = "Versión de la función a la que apunta el alias; es la que tiene el snapshot de SnapStart."
  value       = aws_lambda_alias.live.function_version
}

output "grupo_logs" {
  description = "Grupo de CloudWatch donde se escriben los registros."
  value       = aws_cloudwatch_log_group.lambda.name
}

output "bucket_artefactos" {
  description = "Bucket con los JAR desplegados."
  value       = aws_s3_bucket.artefactos.id
}

output "url_web" {
  description = "URL de la aplicación web."
  value       = var.usar_dominio_propio ? "https://${var.subdominio_web}.${var.dominio}" : (length(aws_cloudfront_distribution.web) > 0 ? "https://${aws_cloudfront_distribution.web[0].domain_name}" : "pendiente de desplegar")
}

output "registros_dns_pendientes" {
  description = "Registros CNAME que hay que crear a mano en Hostinger para validar los certificados."
  value = var.usar_dominio_propio ? {
    for opcion in aws_acm_certificate.principal[0].domain_validation_options :
    opcion.domain_name => {
      nombre = opcion.resource_record_name
      valor  = opcion.resource_record_value
      tipo   = opcion.resource_record_type
    }
  } : {}
}
