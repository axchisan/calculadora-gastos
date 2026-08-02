# 0001 — Flutter como cliente multiplataforma

- **Estado**: Aceptada
- **Fecha**: 2026-08-02

## Contexto

La aplicación debe estar disponible en **web, Android y macOS**, con los mismos datos
sincronizados. Es un proyecto de un solo desarrollador, así que mantener tres bases de código
nativas no es viable.

La interfaz es además exigente: calendario interactivo para marcar días de transporte,
gráficas interactivas de distribución y evolución, edición en línea de montos con recálculo
instantáneo.

## Decisión

Usar **Flutter 3** con Dart, compilando a los tres objetivos desde un único código base.

Arquitectura por capas dentro de `app/lib`:

| Capa | Responsabilidad |
|---|---|
| `presentation/` | Pantallas y widgets |
| `application/` | Estado y casos de uso (Riverpod) |
| `domain/` | Entidades y reglas de negocio puras, sin dependencias de framework |
| `infrastructure/` | Cliente HTTP (Dio), persistencia local (Drift) |

El **motor de cálculo se duplica en `domain/`** para que los totales y las gráficas respondan
al instante mientras se editan valores, sin esperar al servidor. El backend recalcula y
valida antes de persistir, de modo que el servidor sigue siendo la fuente de verdad.

## Alternativas consideradas

**React Native.** Excelente en móvil, pero su soporte de escritorio en macOS es menos maduro
y la versión web exige un stack aparte.

**Aplicación web responsive únicamente.** Sería lo más barato de construir y desplegar, pero
renuncia a la experiencia nativa en móvil, donde se hará la mayor parte de las consultas
rápidas.

**Kotlin Multiplatform con Compose.** Muy sólido en Android y escritorio, pero su soporte web
seguía siendo experimental frente a la madurez de Flutter Web.

## Consecuencias

**Positivas**

- Un solo código base para tres plataformas.
- Recálculo local instantáneo, que además enmascara el cold start de Lambda.
- Las gráficas interactivas se implementan una vez y se comportan igual en todas partes.

**Negativas**

- **La lógica de cálculo queda duplicada** entre Dart y Java. Se acota manteniéndola pura y
  cubriéndola con la misma batería de casos de prueba en ambos lenguajes, con los valores
  esperados definidos en un fichero compartido.
- Flutter Web produce un bundle relativamente pesado y su SEO es limitado, algo irrelevante
  en una aplicación privada tras autenticación.
- **Compilar para macOS requiere Xcode completo** (unos 10 GB), no solo las Command Line
  Tools. Es un requisito puntual del entorno de desarrollo.
