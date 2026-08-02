# Calculadora de Gastos

Aplicación personal de finanzas para planificar el presupuesto mes a mes: sueldo, gastos
fijos, control de pagos, deudas externas, metas de ahorro y un cálculo de transporte que
tiene en cuenta el calendario de festivos de Colombia.

Disponible en **web**, **Android** y **macOS**, con los datos sincronizados entre todos los
dispositivos.

## Qué resuelve

- **Presupuesto mensual**: registrar el sueldo del mes y los gastos fijos, ver cuánto queda
  disponible en tiempo real.
- **Control de pagos**: marcar cada gasto como pendiente o pagado; el saldo se descuenta a
  medida que se paga.
- **Deudas externas**: tarjeta de crédito, préstamos familiares o de amigos, con abonos que
  se integran al cálculo del mes.
- **Transporte**: calcular el gasto real del mes contando los días que efectivamente se
  viaja a la oficina, descontando festivos colombianos, fines de semana y días de trabajo
  remoto, y sumando el pasaje extra de los días de karate.
- **Ahorro**: distribuir el excedente en metas con porcentajes o montos fijos.
- **Gráficas**: evolución del patrimonio, distribución del gasto y avance de deudas.

## Estructura del repositorio

```
calculadora-gastos/
├── app/          Cliente Flutter (web · android · macos)
├── backend/      API REST — Spring Boot 3 · Java 21 · Gradle
├── infra/        Terraform y scripts de despliegue en AWS
├── docs/         Arquitectura, modelo de dominio y decisiones (ADR)
└── .github/      Integración continua
```

## Stack

| Capa | Tecnología | Por qué |
|---|---|---|
| Cliente | Flutter 3 (Dart) | Un solo código para web, Android y macOS |
| API | Spring Boot 3 · Java 21 | Stack conocido; corre en Lambda con SnapStart |
| Cómputo | AWS Lambda + Function URL | 1M peticiones/mes gratis de forma permanente |
| Base de datos | PostgreSQL (Neon) | SQL relacional con JPA/Hibernate y Flyway |
| Frontend hosting | S3 + CloudFront | 1 TB de salida/mes gratis permanente |
| Autenticación | Spring Security + JWT | Sin costo ni infraestructura adicional |

Costo operativo estimado: **~$0.01 USD/mes**. Ver [`docs/COSTOS.md`](docs/COSTOS.md).

## Documentación

- [Arquitectura](docs/ARQUITECTURA.md) — visión general, componentes y despliegue
- [Modelo de dominio](docs/MODELO-DOMINIO.md) — entidades y esquema de base de datos
- [Festivos y transporte](docs/FESTIVOS-Y-TRANSPORTE.md) — Ley Emiliani y motor de cálculo
- [Costos](docs/COSTOS.md) — desglose de gastos en AWS
- [Decisiones de arquitectura](docs/adr/) — registro de decisiones (ADR)

## Requisitos de desarrollo

- Java 21
- Flutter 3.x
- Terraform 1.x
- AWS CLI configurado
- Xcode (solo para compilar la versión de macOS)

## Licencia

Proyecto personal de uso privado.
