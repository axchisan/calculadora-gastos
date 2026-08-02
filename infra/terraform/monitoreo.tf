# ---------------------------------------------------------------------------
# Control de costos
#
# La arquitectura está pensada para vivir dentro del nivel gratuito permanente, así que
# cualquier gasto apreciable indica que algo se configuró mal. El aviso llega mucho antes de
# que la cifra importe.
# ---------------------------------------------------------------------------

resource "aws_budgets_budget" "mensual" {
  name         = "${local.nombre}-mensual"
  budget_type  = "COST"
  limit_amount = tostring(var.umbral_alerta_costo)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Aviso al superar el umbral con el gasto ya incurrido.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.correo_alertas]
  }

  # Aviso anticipado: AWS proyecta el cierre del mes y avisa si va camino de superar el doble
  # del umbral, sin esperar a que ocurra.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 200
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.correo_alertas]
  }
}

# ---------------------------------------------------------------------------
# Alarmas de funcionamiento
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alertas" {
  name = "${local.nombre}-alertas"
}

resource "aws_sns_topic_subscription" "correo" {
  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "email"
  endpoint  = var.correo_alertas
}

resource "aws_cloudwatch_metric_alarm" "errores" {
  alarm_name          = "${local.nombre}-errores"
  alarm_description   = "La API está devolviendo errores de forma sostenida."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  # Sin datos significa que nadie usó la aplicación, no que haya un problema.
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
}

resource "aws_cloudwatch_metric_alarm" "duracion" {
  alarm_name          = "${local.nombre}-duracion"
  alarm_description   = "Las peticiones tardan más de lo esperable; puede indicar que la base de datos no responde."
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  alarm_actions = [aws_sns_topic.alertas.arn]
}
