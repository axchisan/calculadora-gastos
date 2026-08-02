# 0002 — Spring Boot sobre AWS Lambda con SnapStart

- **Estado**: Aceptada
- **Fecha**: 2026-08-02

## Contexto

La cuenta de AWS (`612216903994`) se creó el 21 de junio de 2026, bajo el modelo de free tier
posterior a julio de 2025. No dispone del free tier de 12 meses, por lo que **EC2 y RDS
generan cargo desde el primer día**.

Los costos reales de la alternativa basada en servidor, verificados con la API de precios de
AWS:

| Concepto | Costo mensual |
|---|---|
| EC2 t4g.small | $12.26 |
| IPv4 pública | $3.65 |
| Volumen EBS 10 GB | $0.80 |
| **Total** | **$16.71/mes** |

El trial de t4g.small (750 h/mes) vence el 31 de diciembre de 2026, y los créditos expiran
por las mismas fechas. Es decir, la opción de servidor sale gratis cinco meses y luego cuesta
unos 68.000 COP mensuales de forma indefinida.

Lambda, en cambio, tiene un free tier **permanente** de 1M de peticiones y 400.000 GB-s al
mes, holgadamente por encima del uso previsto de una aplicación personal.

## Decisión

Ejecutar la API como una función Lambda con **Spring Boot 3 y Java 21**, usando
`aws-serverless-java-container-springboot3` para adaptar los eventos de Lambda al
`DispatcherServlet`.

Se habilita **SnapStart**, que toma un snapshot del proceso ya inicializado y reduce el cold
start de 5-15 s a 200-500 ms, sin costo adicional en runtimes de Java.

Se expone mediante **Lambda Function URL** en lugar de API Gateway, porque no factura por
petición y no se necesitan las funciones avanzadas de API Gateway.

El empaquetado es un **ZIP** (fat JAR de ~40 MB), no una imagen de contenedor: ECR solo
ofrece free tier durante 12 meses, del que esta cuenta no dispone.

## Alternativas consideradas

**EC2 t4g.small con Docker.** Es la opción más simple de operar y depurar, sin cold starts y
con PostgreSQL local. Se descarta por los $16.71/mes a partir de enero de 2027, tres órdenes
de magnitud por encima de la alternativa sin servidor.

**Quarkus o Micronaut con compilación nativa.** Arrancan en ~50 ms sin necesidad de
SnapStart. Se descartan porque Spring Boot es el framework que ya se domina, y SnapStart
cierra la brecha de rendimiento lo suficiente para este caso de uso.

**API Gateway.** Añade throttling, planes de uso y autorizadores que aquí no se necesitan, a
cambio de $1.00 por millón de peticiones.

## Consecuencias

**Positivas**

- Costo de cómputo de $0.00 permanente, sin fecha de vencimiento.
- Sin servidores que parchear, monitorear ni escalar.
- El código sigue siendo Spring Boot convencional: los controladores, servicios y
  repositorios son idénticos a los de un despliegue tradicional.

**Negativas**

- La primera petición tras un periodo de inactividad tarda ~300 ms más. Se mitiga con caché
  local en el cliente.
- SnapStart exige cuidado con el estado que se captura en el snapshot: conexiones a base de
  datos y semillas aleatorias deben reinicializarse tras la restauración (mediante los hooks
  `beforeCheckpoint`/`afterRestore` de CRaC).
- Depurar en local requiere ejecutar la aplicación como Spring Boot normal y validar aparte
  el comportamiento en Lambda.
- Cada despliegue debe publicar una nueva versión de la función para que SnapStart genere el
  snapshot correspondiente.
