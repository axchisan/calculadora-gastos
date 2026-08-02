# 0005 — Monorepo

- **Estado**: Aceptada
- **Fecha**: 2026-08-02

## Contexto

El proyecto tiene tres componentes que evolucionan juntos: el cliente Flutter, la API de
Spring Boot y la infraestructura en Terraform. Lo desarrolla una sola persona.

El punto de fricción principal es el **contrato de la API**: casi todo cambio en un endpoint
obliga a un cambio correspondiente en el cliente.

## Decisión

Un único repositorio con esta estructura:

```
calculadora-gastos/
├── app/          Cliente Flutter (web · android · macos)
├── backend/      API Spring Boot 3 · Java 21 · Gradle
├── infra/        Terraform y scripts de despliegue
├── docs/         Arquitectura, dominio y ADRs
└── .github/      Integración continua
```

La integración continua usa filtros por ruta, de modo que un cambio en `app/` no dispara la
compilación del backend y viceversa.

## Alternativas consideradas

**Repositorios separados.** Permiten ciclos de publicación independientes y una CI más simple
en cada uno. Se descarta porque obligaría a coordinar manualmente los cambios de contrato
entre repositorios y a mantener dos juegos de issues para un proyecto de un solo
desarrollador.

## Consecuencias

**Positivas**

- Un cambio de API y su cliente viajan en el mismo commit, siempre coherentes.
- Un único lugar para issues, historial y documentación.
- Los casos de prueba compartidos del motor de cálculo (Dart y Java) pueden vivir en un
  fichero común.

**Negativas**

- La CI necesita filtros por ruta para no compilar todo en cada cambio.
- El repositorio crece más rápido y el historial mezcla dominios distintos; se acota con
  prefijos de ámbito en los mensajes de commit (`app:`, `backend:`, `infra:`, `docs:`).
- Si algún día se quisiera abrir el código de una sola parte, habría que extraerla.
