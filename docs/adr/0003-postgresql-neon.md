# 0003 — PostgreSQL gestionado en Neon, fuera de AWS

- **Estado**: Aceptada
- **Fecha**: 2026-08-02

## Contexto

El dominio del problema es marcadamente relacional: meses que agrupan gastos, gastos que
provienen de plantillas, deudas con múltiples abonos, metas de ahorro con movimientos. Las
consultas requieren agregaciones (`SUM` por categoría, evolución mensual, saldos acumulados)
que son el terreno natural de SQL.

Al mismo tiempo, ninguna base de datos gestionada dentro de AWS resulta gratuita para esta
cuenta:

| Opción en AWS | Costo mensual |
|---|---|
| RDS db.t4g.micro | ~$12.00 |
| Aurora Serverless v2 (escalada a cero) | ~$1.00 solo de almacenamiento, ~15 s para despertar |
| DynamoDB | $0.00 pero NoSQL |

## Decisión

Usar **PostgreSQL gestionado en Neon**, cuyo free tier es permanente y suficiente para el
volumen previsto (0.5 GB), accediendo con **JPA/Hibernate** y migraciones versionadas con
**Flyway**.

Al vivir la base de datos fuera de la VPC, **Lambda no necesita configuración de VPC**, lo
que evita el **NAT Gateway (~$32.40/mes)** que Lambda requeriría para alcanzar una base de
datos privada y salir a internet simultáneamente. Este es el costo oculto que suele hacer
inviables las arquitecturas sin servidor con RDS.

Para el pooling se usa el endpoint con **PgBouncer** de Neon y un HikariCP limitado
(`maximum-pool-size: 2`), acorde a cómo Lambda multiplica instancias concurrentes.

## Alternativas consideradas

**DynamoDB.** Es la única base de datos con free tier permanente dentro de AWS (25 GB, 25
WCU/RCU). Los patrones de acceso de esta aplicación encajarían razonablemente con un diseño
de tabla única. Se descarta porque las agregaciones y los reportes históricos tendrían que
resolverse en memoria en la aplicación, y porque se pierde la capacidad de hacer consultas
analíticas ad-hoc sobre los propios datos financieros.

**RDS PostgreSQL.** La opción canónica, pero $12/mes desde el primer día, más el NAT Gateway
si se quisiera acceder desde Lambda en VPC.

**Aurora Serverless v2 con escalado a cero.** Sigue cobrando almacenamiento estando pausada
(~$1/mes mínimo) y tarda unos 15 segundos en reanudarse, lo que se sumaría al cold start de
Lambda.

**Supabase.** Free tier comparable al de Neon, pero incluye un stack completo (auth, storage,
realtime) que aquí no se usa; Neon es más acotado al problema.

## Consecuencias

**Positivas**

- SQL relacional completo, con JPA, Hibernate y Flyway, igual que en un proyecto Spring Boot
  convencional.
- Costo $0.00 y ahorro de $32.40/mes al no necesitar NAT Gateway.
- Neon escala a cero automáticamente y gestiona sus propios respaldos.

**Negativas**

- **Dependencia de un proveedor externo a AWS**: si Neon modifica su plan gratuito, hay que
  migrar. El riesgo se acota manteniendo el esquema en PostgreSQL estándar, sin extensiones
  propietarias, de modo que la migración a RDS u otro proveedor sea un `pg_dump`/`pg_restore`.
- La latencia entre Lambda y Neon depende de la red pública. Se mitiga alojando ambos en la
  misma región (`us-east-1`).
- El tráfico viaja fuera de AWS, por lo que la conexión debe exigir TLS obligatorio.
- Se añade un segundo panel de control y un segundo juego de credenciales que gestionar.

## Mitigación del riesgo de proveedor

1. Esquema PostgreSQL estándar, sin extensiones específicas de Neon.
2. Volcado semanal automático a S3 mediante `pg_dump`, versionado.
3. La cadena de conexión vive en SSM Parameter Store: cambiar de proveedor es cambiar un
   parámetro y redesplegar.
