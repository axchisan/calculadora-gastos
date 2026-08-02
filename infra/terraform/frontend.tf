# ---------------------------------------------------------------------------
# Aplicación web
#
# El bucket permanece privado: CloudFront accede mediante Origin Access Control, de modo que
# los archivos no son alcanzables saltándose la distribución.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "web" {
  bucket = local.bucket_web
}

resource "aws_s3_bucket_public_access_block" "web" {
  bucket                  = aws_s3_bucket.web.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "web" {
  name                              = "${local.nombre}-web"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.web.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.web[0].arn
        }
      }
    }]
  })
}

resource "aws_cloudfront_distribution" "web" {
  count = 1

  enabled             = true
  default_root_object = "index.html"
  comment             = "${local.nombre} · aplicación web"
  price_class         = "PriceClass_100" # Norteamérica y Europa: suficiente y lo más barato.

  aliases = var.usar_dominio_propio ? ["${var.subdominio_web}.${var.dominio}"] : []

  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id                = "s3-web"
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-web"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Políticas gestionadas por AWS: CachingOptimized.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # Flutter Web resuelve el enrutamiento en el cliente, así que cualquier ruta desconocida
  # debe servir index.html en vez de un error.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !var.usar_dominio_propio
    acm_certificate_arn            = var.usar_dominio_propio ? aws_acm_certificate_validation.principal[0].certificate_arn : null
    ssl_support_method             = var.usar_dominio_propio ? "sni-only" : null
    minimum_protocol_version       = var.usar_dominio_propio ? "TLSv1.2_2021" : null
  }
}

# ---------------------------------------------------------------------------
# API bajo dominio propio
#
# Las Function URL no admiten dominios personalizados, así que se pone CloudFront delante
# únicamente para aportar el nombre y el certificado. Sin dominio propio no hace falta: se usa
# directamente la URL que asigna AWS.
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "api" {
  count = var.usar_dominio_propio ? 1 : 0

  enabled     = true
  comment     = "${local.nombre} · API"
  price_class = "PriceClass_100"
  aliases     = ["${var.subdominio_api}.${var.dominio}"]

  origin {
    # La Function URL viene como https://xxxx.lambda-url.region.on.aws/ y CloudFront espera
    # solo el nombre de host.
    domain_name = replace(replace(aws_lambda_function_url.api.function_url, "https://", ""), "/", "")
    origin_id   = "lambda-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "lambda-api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # CachingDisabled: las respuestas dependen del usuario autenticado y no deben compartirse.
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AllViewerExceptHostHeader: reenvía cabeceras y cuerpo, pero deja que Lambda reciba su
    # propio Host, que es lo que espera la firma de la Function URL.
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.principal[0].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
