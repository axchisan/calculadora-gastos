# Calculadora de Gastos — guía para trabajar en el proyecto

App personal de finanzas: presupuesto mensual, gastos del día a día,
deudas, créditos, transporte, cuentas reales y un sueldo cobrado en dólares. La usa a diario en
el teléfono Android, en el Mac y en la web.

**Estado actual y lo pendiente: [docs/ESTADO.md](docs/ESTADO.md).** Léelo antes de cambiar nada.

## Stack y dónde vive cada cosa

| Pieza | Tecnología | Producción |
|---|---|---|
| `backend/` | Spring Boot 3, Java 21, JPA + Flyway | AWS Lambda con SnapStart → `https://api.axchisan.com` |
| `app/` | Flutter 3.44.8 (Android, macOS, web), Riverpod, go_router | APK por cable · `/Applications/Mis gastos.app` · `https://gastos.axchisan.com` |
| Base de datos | PostgreSQL en Neon | credenciales en `.env.neon` (no versionado) |
| `infra/terraform` | Lambda, S3, CloudFront, SSM | cuenta AWS `612216903994` (Free Plan, caduca ~dic 2026) |

Documentación de detalle en `docs/`: arquitectura, modelo de dominio, API, despliegue, apps,
captura de pagos, festivos y transporte, costos.

## Comandos

```bash
# Backend: pruebas (necesitan el PostgreSQL local con la base gastos_test)
cd backend
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
./gradlew test          # el toolchain descarga Java 21 solo; el Java 25 del sistema rompe Gradle
# Si una migración se aplicó rota en local: dropdb -h localhost gastos_test && createdb -h localhost gastos_test -O gastos

# App
cd app
flutter analyze && dart format --set-exit-if-changed lib test && flutter test
flutter build apk --release --split-per-abi --dart-define=API_URL=https://api.axchisan.com
flutter build macos --release --dart-define=API_URL=https://api.axchisan.com
../scripts/instalar-en-el-telefono.sh     # instala por adb, con el teléfono por USB
# Mac: cerrar «Mis gastos», reemplazar /Applications/Mis gastos.app con el build y abrirla
```

**Desplegar = `git push` a `main`.** GitHub Actions corre las pruebas y despliega el backend
(publica versión de Lambda; Flyway migra al arrancar) y la web. Las apps de teléfono y Mac se
compilan e instalan a mano. Commit y push solo cuando el usuario lo pida o lo haya autorizado
para esa tarea.

## Trampas conocidas

- **Hibernate valida el esquema** (`ddl-auto: validate`). Una columna con tipo distinto al de
  la entidad tumba la API al arrancar (pasó con `char(3)` vs `varchar`). Las pruebas de
  integración lo detectan: córrelas siempre antes de subir una migración.
- **La CI de la web falla por formato** si no se ejecutó `dart format`. Flutter está fijado a
  3.44.8 en `.github/workflows/web.yml`: Flutter 3.50 marca `material.dart` como obsoleto.
- **Xcode 26 exige macOS 12** como mínimo (ya configurado en Podfile y Runner).
- Flutter tiene `jdk-dir` apuntando al Temurin 17; el `openjdk@21` de Homebrew ya no existe.
- Las cuotas de `credit_installments` se cruzan con el mes **calendario**, no con el mes
  presupuestal del 28 al 27 (ver `ServicioResumen`).
- En las pruebas la consulta de la TRM está desactivada (`app.trm.habilitada: false`).

## Convenciones

- Todo en español: código (`ServicioSueldo`, `calcularCuotas`), comentarios, commits y docs.
- Commits estilo `feat: …`, `fix: …`, `ci: …`, con un cuerpo que explica el porqué.
- Los comentarios explican decisiones y casos reales, no lo que hace la línea.
- Dinero en `numeric(14,2)` / `BigDecimal`; en Dart `double` formateado con `Formato.dinero`.
  Para presupuestar se redondea hacia abajo.
- Cada función nueva lleva pruebas: unitarias para el cálculo e integración para la API.

## Datos de producción y privacidad

**El repositorio es público.** Nada personal (saldos, deudas, personas, teléfonos, correos,
ids de usuario) va en archivos versionados, commits ni PRs. Eso vive en `CLAUDE.local.md`
(sin versionar) y en la memoria del proyecto.

El usuario pide de vez en cuando «sincronizar» la app con sus bancos: las convenciones de esa
tarea están en `CLAUDE.local.md`. Antes de escribir en Neon: `pg_dump` a
`~/respaldos-gastos/` y una sola transacción.
