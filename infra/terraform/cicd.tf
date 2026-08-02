# ---------------------------------------------------------------------------
# Despliegue desde GitHub Actions
#
# Se usa OIDC en lugar de claves de acceso: GitHub obtiene credenciales temporales al
# ejecutarse, así no hay ninguna clave permanente guardada en los secretos del repositorio que
# pueda filtrarse o quedar olvidada.
# ---------------------------------------------------------------------------

variable "repositorio_github" {
  description = "Repositorio autorizado a desplegar, en formato usuario/repositorio."
  type        = string
  default     = "axchisan/calculadora-gastos"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Huella del certificado de GitHub. AWS ya no la valida para este proveedor, pero la API
  # sigue exigiendo el campo.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "despliegue" {
  name = "${local.nombre}-despliegue"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Restringe el rol a este repositorio: sin esta condición, cualquier repositorio de
        # GitHub podría asumirlo.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.repositorio_github}:*"
        }
      }
    }]
  })
}

# Permisos acotados a lo que el despliegue necesita: subir el artefacto, actualizar la
# función, publicar la versión y refrescar la web.
resource "aws_iam_role_policy" "despliegue" {
  name = "desplegar"
  role = aws_iam_role.despliegue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SubirArtefactos"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.artefactos.arn,
          "${aws_s3_bucket.artefactos.arn}/*"
        ]
      },
      {
        Sid    = "PublicarWeb"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.web.arn,
          "${aws_s3_bucket.web.arn}/*"
        ]
      },
      {
        Sid    = "ActualizarFuncion"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:PublishVersion",
          "lambda:UpdateAlias",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetAlias"
        ]
        Resource = [
          aws_lambda_function.api.arn,
          "${aws_lambda_function.api.arn}:*"
        ]
      },
      {
        Sid      = "InvalidarCache"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
        Resource = aws_cloudfront_distribution.web[0].arn
      }
    ]
  })
}

output "rol_despliegue" {
  description = "Rol que asume GitHub Actions. Se configura como secreto AWS_ROLE_ARN en el repositorio."
  value       = aws_iam_role.despliegue.arn
}

output "bucket_web" {
  description = "Bucket donde se publica la aplicación web."
  value       = aws_s3_bucket.web.id
}

output "distribucion_web" {
  description = "Distribución de CloudFront de la web; se invalida en cada despliegue."
  value       = aws_cloudfront_distribution.web[0].id
}
