# Registro de decisiones de arquitectura (ADR)

Cada archivo documenta una decisión técnica relevante: el contexto en que se tomó, las
alternativas consideradas y las consecuencias asumidas. El objetivo es que dentro de un año
se pueda entender **por qué** algo está hecho de cierta forma, sin tener que reconstruirlo.

| # | Decisión | Estado | Fecha |
|---|---|---|---|
| [0001](0001-flutter-multiplataforma.md) | Flutter como cliente multiplataforma | Aceptada | 2026-08-02 |
| [0002](0002-lambda-spring-boot.md) | Spring Boot sobre AWS Lambda con SnapStart | Aceptada | 2026-08-02 |
| [0003](0003-postgresql-neon.md) | PostgreSQL gestionado en Neon, fuera de AWS | Aceptada | 2026-08-02 |
| [0004](0004-autenticacion-jwt.md) | Autenticación JWT propia con Spring Security | Aceptada | 2026-08-02 |
| [0005](0005-monorepo.md) | Monorepo | Aceptada | 2026-08-02 |

## Formato

```markdown
# NNNN — Título

- **Estado**: Propuesta | Aceptada | Reemplazada por NNNN | Obsoleta
- **Fecha**: AAAA-MM-DD

## Contexto
## Decisión
## Alternativas consideradas
## Consecuencias
```
