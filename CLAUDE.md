# Calculadora de Gastos — guía para trabajar en el proyecto

App personal de finanzas: presupuesto mensual, gastos del día a día,
deudas, créditos, transporte, cuentas reales y un sueldo cobrado en dólares. La usa a diario en
el teléfono Android, en el Mac y en la web.

**Estado actual y lo pendiente: [docs/ESTADO.md](docs/ESTADO.md).** Léelo antes de cambiar nada.

**Rediseño v2 terminado** (versión 2.0.0, 23 nov 2026; ver [docs/rediseno/PLAN.md](docs/rediseno/PLAN.md)).
La referencia visual sigue siendo el prototipo aprobado, en `privado/prototipo-v2.html` (ignorado
por git). Cada cambio se prueba en el emulador con los datos de producción antes de publicarse.

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
# Con el emulador abierto a la vez: ANDROID_SERIAL=<serial del teléfono> ../scripts/instalar-…
# Catálogo de componentes del rediseño (entra por Mi cuenta): añadir --dart-define=CATALOGO=true
~/Library/Android/sdk/emulator/emulator -avd prueba35b   # emulador para revisar fases
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
- **Iconos**: fuentes Phosphor propias (`app/assets/iconos/`, códigos en `ui/comun/iconos.dart`);
  el paquete `phosphor_flutter` no compila con Flutter 3.44. Todo `IconData` debe ser `const`
  (también en las ramas de un `switch`) o la compilación de publicación falla.
- **SnackBar con acción** no se cierra solo en esta versión de Flutter: usar `persist: false`.
- **Clase `Radio`** choca con el widget de Material: los radios del tema son `Radios`.

## Convenciones

- Todo en español: código (`ServicioSueldo`, `calcularCuotas`), comentarios, commits y docs.
- Commits estilo `feat: …`, `fix: …`, `ci: …`, con un cuerpo que explica el porqué.
- Los comentarios explican decisiones y casos reales, no lo que hace la línea.
- Dinero en `numeric(14,2)` / `BigDecimal`; en Dart `double` formateado con `Formato.dinero`.
  Para presupuestar se redondea hacia abajo.
- Cada función nueva lleva pruebas: unitarias para el cálculo e integración para la API.
- **Interfaz (rediseño v2)**: colores solo de `context.colores` (tokens en `core/tema.dart`),
  piezas de `ui/comun/componentes.dart`, importes con `Formato.pesos` (sin centavos en listas).
  Borrar siempre con `borrarConDeshacer`.
- **Datos**: leer siempre por `ClienteApi.obtener` (caché y sin conexión van solos) y declarar en
  cada proveedor sus rutas con `ref.alActualizarse`. Las altas del día a día llevan `id` generado
  en la app y `sinConexion: Superposicion(...)` para poder hacerse sin red.

## Datos de producción y privacidad

**El repositorio es público.** Nada personal (saldos, deudas, personas, teléfonos, correos,
ids de usuario) va en archivos versionados, commits ni PRs. **Tampoco como datos de ejemplo** en
pruebas, catálogos o comentarios: usar cifras inventadas. Lo personal vive en
`CLAUDE.local.md` (sin versionar) y en la memoria del proyecto.

El usuario pide de vez en cuando «sincronizar» la app con sus bancos: las convenciones de esa
tarea están en `CLAUDE.local.md`. Antes de escribir en Neon: `pg_dump` a
`~/respaldos-gastos/` y una sola transacción.
