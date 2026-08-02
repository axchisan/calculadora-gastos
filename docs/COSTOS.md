# Costos de operación en AWS

Cuenta AWS: `612216903994` · región `us-east-1`

## Contexto: esta cuenta no tiene el free tier de 12 meses

La cuenta fue creada el **21 de junio de 2026**, después del cambio de política de AWS de
julio de 2025. Eso significa:

- **No aplica** el free tier clásico de 12 meses (EC2, RDS, S3 gratis el primer año).
- **Sí aplica** el modelo de créditos: plan `PAID` con **$142.87 USD** disponibles,
  que expiran alrededor del **21 de diciembre de 2026**.
- **Sí aplica** el *Always Free*: límites mensuales que **no expiran nunca**.

Por eso la arquitectura se diseñó para vivir dentro del *Always Free*, y no para aprovechar
un año gratuito que esta cuenta no tiene.

## Costo mensual estimado

Estimación para un uso personal (~5.000 peticiones/mes, ~20 MB de aplicación web).

| Servicio | Límite gratuito | Uso estimado | Costo |
|---|---|---|---|
| Lambda — peticiones | 1M/mes · permanente | ~5.000 | $0.00 |
| Lambda — cómputo | 400.000 GB-s/mes · permanente | ~500 GB-s | $0.00 |
| Lambda Function URL | sin cargo adicional | — | $0.00 |
| SnapStart (Java) | sin cargo adicional | — | $0.00 |
| CloudFront — salida | 1 TB/mes · permanente | <1 GB | $0.00 |
| CloudFront — peticiones | 10M/mes · permanente | ~20.000 | $0.00 |
| Transferencia a internet | 100 GB/mes · permanente | <1 GB | $0.00 |
| CloudWatch Logs | 5 GB/mes · permanente | <100 MB | $0.00 |
| ACM (certificados TLS) | gratuito siempre | 2 certificados | $0.00 |
| SSM Parameter Store | tier estándar gratuito | ~5 parámetros | $0.00 |
| **S3 — almacenamiento** | sin free tier en esta cuenta | 0.02 GB × $0.023 | **$0.0005** |
| **S3 — PUT (despliegues)** | sin free tier en esta cuenta | ~800 PUT × $0.005/1000 | **$0.004** |
| **S3 — GET** | sin free tier en esta cuenta | mínimo (CloudFront cachea) | **$0.0004** |
| PostgreSQL (Neon) | free tier permanente | 0.5 GB | $0.00 |
| DNS (Hostinger) | ya contratado | — | $0.00 |
| | | **TOTAL** | **~$0.005/mes** |

Menos de un centavo de dólar al mes — unos **20 pesos colombianos**.

### Qué se paga y cuándo

| Periodo | Costo real |
|---|---|
| Agosto 2026 – diciembre 2026 | **$0.00** — cubierto por los créditos |
| Enero 2027 en adelante | **~$0.005-0.05/mes** cargado a la tarjeta |

## Costos evitados por diseño

Estos son los cargos que suelen sorprender en arquitecturas similares y que la arquitectura
elegida evita deliberadamente:

| Costo evitado | Monto | Cómo se evita |
|---|---|---|
| NAT Gateway | ~$32.40/mes | La base de datos está fuera de la VPC, así que Lambda no necesita VPC |
| EC2 t4g.small | ~$12.26/mes | Cómputo sin servidor |
| IPv4 pública | ~$3.65/mes | No hay instancias con IP fija |
| RDS db.t4g.micro | ~$12.00/mes | PostgreSQL gestionado en Neon |
| Volumen EBS | ~$0.80/mes | Sin servidores |
| Route 53 (zona alojada) | $0.50/mes | El DNS sigue en Hostinger |
| API Gateway | $1.00/millón | Lambda Function URL |
| ECR (tras 12 meses) | ~$0.10/mes | Despliegue en ZIP, no en contenedor |
| **Total evitado** | **~$62.71/mes** | |

## Protecciones contra sorpresas

1. **Alerta de presupuesto**: notificación por correo si el gasto mensual supera **$1 USD**,
   y una segunda alerta al superar el 80% de los créditos restantes.
2. **Retención de logs a 7 días**: sin esto, CloudWatch acumula logs indefinidamente y el
   almacenamiento empieza a cobrarse una vez superado el límite gratuito.
3. **Sin recursos con costo fijo**: no hay nada encendido que cobre por horas. Si la app no
   se usa, el costo tiende a cero.
4. **Revisión de costos en CI**: `terraform plan` en cada cambio de infraestructura para
   detectar recursos con cargo antes de crearlos.

## Cómo llegar a $0.00 exactos

Si se quiere eliminar incluso ese medio centavo, el frontend puede salir de S3:

| Opción | Costo | Contrapartida |
|---|---|---|
| Cloudflare Pages | $0.00 permanente | El frontend deja de estar en AWS |
| Hostinger (hosting ya contratado) | $0.00 adicional | Despliegue por FTP, sin CDN de AWS |
| S3 + CloudFront (actual) | ~$0.005/mes | Todo en AWS, un solo proveedor |

Es una decisión que solo afecta el último paso del despliegue; cambiar de opción no requiere
tocar el código de la aplicación.

## Verificación

```bash
# Créditos restantes y tipo de plan
aws freetier get-account-plan-state --region us-east-1

# Consumo del free tier
aws freetier get-free-tier-usage --region us-east-1

# Costo del mes en curso
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date -v+1m +%Y-%m-01) \
  --granularity MONTHLY --metrics UnblendedCost
```
