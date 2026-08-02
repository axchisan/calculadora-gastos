variable "region" {
  description = "Región de AWS. Debe coincidir con la de la base de datos en Neon para no añadir latencia, y CloudFront exige us-east-1 para sus certificados."
  type        = string
  default     = "us-east-1"
}

variable "ambiente" {
  description = "Entorno desplegado."
  type        = string
  default     = "produccion"
}

variable "dominio" {
  description = "Dominio raíz. El DNS vive en Hostinger, no en Route 53."
  type        = string
  default     = "axchisan.com"
}

variable "subdominio_web" {
  description = "Subdominio de la aplicación web."
  type        = string
  default     = "gastos"
}

variable "subdominio_api" {
  description = "Subdominio de la API."
  type        = string
  default     = "api"
}

variable "usar_dominio_propio" {
  description = <<-EOT
    Activa los certificados y las distribuciones de CloudFront con dominio propio.

    Se despliega en dos pasos a propósito: primero la API sobre la URL que asigna AWS, que
    funciona de inmediato y permite verificar todo; y solo después los dominios, que requieren
    crear registros CNAME a mano en Hostinger y esperar la validación.
  EOT
  type        = bool
  default     = false
}

variable "memoria_lambda" {
  description = <<-EOT
    Memoria de la función, en MB.

    En Lambda la CPU se asigna en proporción a la memoria, así que subirla acelera el arranque
    de Spring. Con 1024 MB la ejecución es lo bastante corta para que el consumo de GB-segundo
    siga muy por debajo del límite gratuito.
  EOT
  type        = number
  default     = 1024
}

variable "timeout_lambda" {
  description = "Tiempo máximo por petición, en segundos. Cubre el arranque en frío de la base de datos suspendida en Neon."
  type        = number
  default     = 30
}

variable "retencion_logs_dias" {
  description = "Días que se conservan los registros. Sin un límite, CloudWatch acumula logs indefinidamente y acaba generando cargo."
  type        = number
  default     = 7
}

variable "umbral_alerta_costo" {
  description = "Gasto mensual en dólares que dispara el aviso por correo."
  type        = number
  default     = 1
}

variable "correo_alertas" {
  description = "Dirección a la que llegan los avisos de presupuesto."
  type        = string
  default     = "claudecode653@gmail.com"
}

variable "ruta_paquete" {
  description = "Paquete de despliegue construido con ./gradlew paqueteLambda. Lleva las clases en la raíz y las dependencias en lib/, que es el formato que espera el runtime de Java."
  type        = string
  default     = "../../backend/build/distributions/backend-lambda.zip"
}
