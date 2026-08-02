# ---------------------------------------------------------------------------
# Almacén de artefactos
#
# El paquete pesa unos 67 MB, por encima del límite de 50 MB que admite la subida directa a
# Lambda, así que se despliega desde S3.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "artefactos" {
  bucket = local.bucket_artefactos
}

resource "aws_s3_bucket_public_access_block" "artefactos" {
  bucket                  = aws_s3_bucket.artefactos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artefactos" {
  bucket = aws_s3_bucket.artefactos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artefactos" {
  bucket = aws_s3_bucket.artefactos.id

  rule {
    id     = "purgar-versiones-antiguas"
    status = "Enabled"

    filter {}

    # Conservar todas las versiones del JAR acumularía almacenamiento sin utilidad: para
    # volver atrás basta con un par de despliegues previos.
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_object" "paquete" {
  bucket = aws_s3_bucket.artefactos.id
  key    = "lambda/backend.zip"
  source = var.ruta_paquete

  # Fuerza la subida cuando cambia el contenido, no solo el nombre del archivo.
  etag = filemd5(var.ruta_paquete)
}

# ---------------------------------------------------------------------------
# Permisos
# ---------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name = "${local.nombre}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# La función solo puede leer sus propios parámetros, no los de toda la cuenta.
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "leer-parametros"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ]
      Resource = "arn:aws:ssm:${var.region}:${local.cuenta}:parameter/${local.nombre}/*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Función
# ---------------------------------------------------------------------------

# Se crea explícitamente para fijar la retención. Si lo creara Lambda por su cuenta, quedaría
# sin caducidad y los registros se acumularían indefinidamente.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.nombre}-api"
  retention_in_days = var.retencion_logs_dias
}

resource "aws_lambda_function" "api" {
  function_name = "${local.nombre}-api"
  role          = aws_iam_role.lambda.arn
  handler       = "com.axchisan.gastos.lambda.LambdaHandler::handleRequest"
  runtime       = "java21"
  architectures = ["arm64"] # Graviton: más barato por GB-segundo que x86.

  s3_bucket        = aws_s3_bucket.artefactos.id
  s3_key           = aws_s3_object.paquete.key
  s3_object_version = aws_s3_object.paquete.version_id
  source_code_hash = filebase64sha256(var.ruta_paquete)

  memory_size = var.memoria_lambda
  timeout     = var.timeout_lambda

  # SnapStart toma un snapshot del proceso ya inicializado y lo restaura en cada arranque en
  # frío. Reduce el arranque de Spring Boot de varios segundos a unos cientos de milisegundos,
  # y no tiene costo adicional en Java. Requiere publicar una versión.
  snap_start {
    apply_on = "PublishedVersions"
  }

  publish = true

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE = "aws"
      # Las credenciales llegan desde SSM al arrancar, no como variables de entorno.
      SPRING_CONFIG_IMPORT = "aws-parameterstore:/${local.nombre}/"
      # El recolector serial evita los hilos de coordinación de G1, que no rinden con la
      # fracción de vCPU que asigna Lambda a este tamaño de memoria.
      JAVA_TOOL_OPTIONS = "-XX:+UseSerialGC"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

# El alias da un punto de entrada estable: la URL no cambia aunque se publiquen versiones
# nuevas, y apunta siempre a una versión publicada, que es lo que activa SnapStart.
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.api.function_name
  function_version = aws_lambda_function.api.version
}

# ---------------------------------------------------------------------------
# Punto de entrada HTTP
#
# Se usa Function URL en lugar de API Gateway porque no cobra por petición y no se necesitan
# throttling ni autorizadores: la autenticación la resuelve Spring Security dentro.
# ---------------------------------------------------------------------------

# Declarar la URL como pública no basta: Lambda exige además una política que autorice la
# invocación, o responde 403 a todo.
#
# Y hacen falta DOS permisos, no uno. Desde octubre de 2025, las Function URL creadas a partir
# de esa fecha requieren tanto `lambda:InvokeFunctionUrl` como `lambda:InvokeFunction`;
# conceder solo el primero devuelve 403 con AccessDeniedException, sin ninguna pista de que
# falte el segundo. La mayoría de ejemplos publicados son anteriores al cambio y solo muestran
# el primero.
#
# La autenticación real la aplica Spring Security dentro de la función, que es quien conoce
# los tokens.
resource "aws_lambda_permission" "url_invocar_url" {
  statement_id           = "PermitirInvocacionDeLaUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.api.function_name
  qualifier              = aws_lambda_alias.live.name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "url_invocar_funcion" {
  statement_id  = "PermitirInvocacionDeLaFuncion"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  qualifier     = aws_lambda_alias.live.name
  principal     = "*"

  # Este permiso no admite la condición FunctionUrlAuthType, sino esta otra, que limita la
  # invocación a las peticiones que llegan por la URL. Sin ella, cualquier principal de AWS
  # podría invocar la función directamente por la API.
  invoked_via_function_url = true
}

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  qualifier          = aws_lambda_alias.live.name
  authorization_type = "NONE"

  cors {
    allow_origins = [
      "https://${var.subdominio_web}.${var.dominio}",
      "http://localhost:*"
    ]
    # No se incluye OPTIONS: las peticiones preflight las responde la propia Function URL, y
    # además su validación rechaza cualquier método de más de seis caracteres.
    allow_methods     = ["GET", "POST", "PUT", "PATCH", "DELETE"]
    allow_headers     = ["authorization", "content-type"]
    max_age           = 3600
    allow_credentials = false
  }
}
