# Estado de la aplicación

Actualizado el **22 de noviembre de 2026** (noche). Este documento resume cómo está todo y qué
falta, para retomar el trabajo sin tener que reconstruirlo.

## Versiones en uso

| Pieza | Versión | Dónde |
|---|---|---|
| App en el teléfono y la web | **1.12.0+19** (commit `2e428df`) | APK instalado por cable · gastos.axchisan.com |
| App en el Mac | **1.10.0+17** | `/Applications/Mis gastos.app`. Se actualiza al terminar el rediseño, no antes |
| Backend | commit `2e428df` | Lambda `calculadora-gastos-api`, alias `live` |
| Esquema de base de datos | migración **V8** | Neon, proyecto de la Calculadora (3b no necesitó migración) |
| Pruebas | backend **276**, app **124** | todas en verde |

## En curso: rediseño v2

El usuario pidió una reestructuración completa del diseño: claro, minimalista y pensado para
uso personal, no para un contador. Documentos:

- **[docs/rediseno/AUDITORIA.md](rediseno/AUDITORIA.md)**: hallazgos pantalla por pantalla con
  gravedad.
- **[docs/rediseno/PLAN.md](rediseno/PLAN.md)**: principios, nueva estructura de 4 pestañas,
  fases con su estado, diseño de la caché y la cola sin conexión, y trabajo posterior.
- El **prototipo aprobado** (HTML navegable con datos reales) está en `privado/prototipo-v2.html`,
  carpeta ignorada por git. Es la referencia visual de las fases que faltan.

| Fase | Estado |
|---|---|
| 0. Deshacer al borrar | Publicada |
| 1. Prototipo | Aprobado el 22 nov |
| 2. Sistema de diseño y tema claro | Publicada (1.11.0) |
| 3a. Lectura local de todo, precarga, aviso sin conexión | Publicada (1.11.0) |
| 3b. Cola para apuntar sin conexión | Publicada (1.12.0) |
| **3c. ETag y `GET /api/inicio`** | **Siguiente** |
| 4. Navegación de 4 pestañas e Inicio nuevo | Pendiente |
| 5. Movimientos | Pendiente |
| 6. Deudas (total real, proyección) | Pendiente |
| 7. Análisis | Pendiente |
| 8. Pantallas secundarias | Pendiente |
| 9. Pulido y versión 2.0.0 (también en el Mac) | Pendiente |

**Forma de trabajar acordada**: cada fase se prueba en el emulador (`prueba35b`, el usuario
inicia sesión) con los datos de producción, se publica (push a `main`) y se instala en el
teléfono. En el Mac se instala solo al terminar todo el rediseño.

**Después del rediseño**: investigar a fondo cómo registrar movimientos solos (Bancolombia
primero). La captura por notificaciones no ha funcionado en el uso real (ver PLAN, apartado 6).

## Cómo está hecho lo nuevo

- **Tema** (`app/lib/core/tema.dart`): tokens en `Colores` (ThemeExtension, claro y oscuro),
  `Espacio`, `Radios` y `Tipo` (Manrope empaquetada en `assets/fuentes/`, cifras tabulares). El
  tema de Material se arma desde esos tokens. La elección Claro / Oscuro / Sistema vive en
  `estado/apariencia.dart` y hoy se cambia en Mi cuenta → Apariencia. Arranca en claro.
- **Componentes** (`app/lib/ui/comun/componentes.dart`): `CifraPrincipal`, `Importe`, `Panel`,
  `Seccion`, `Fila`, `FechaCorta`, `Etiqueta`, `CajaAviso`, `EstadoVacio`, `abrirHoja`.
  `Formato.pesos` muestra importes sin centavos. Las pantallas nuevas se arman con estas piezas.
- **Iconos** (`app/lib/ui/comun/iconos.dart`): Phosphor (MIT) con fuentes propias en
  `assets/iconos/`. El paquete `phosphor_flutter` no compila con Flutter 3.44. Los `IconData`
  deben ser `const`, porque si no la compilación de publicación falla al recortar los iconos.
- **Catálogo de componentes**: compilar con `--dart-define=CATALOGO=true` y entrar por Mi cuenta.
- **Deshacer** (`ui/comun/deshacer.dart`): `borrarConDeshacer` esconde el elemento
  (`ocultosProvider`) y borra en el servidor solo si el aviso de 5 s vence. Las listas filtran con
  `sinOcultos`.
- **Caché de lecturas** (`datos/cliente_api.dart`): cada GET correcto se guarda por usuario y
  ruta en `CacheLocal` (SharedPreferences) y se sirve con *stale-while-revalidate*. Tras un
  cambio hecho en la app, las lecturas van primero al servidor. Cada proveedor declara sus rutas
  con `ref.alActualizarse([...])` para repintarse cuando llega una versión nueva. La precarga de
  todas las secciones está en `estado/red.dart`, y la franja de estado en `ui/comun/aviso_red.dart`.
- **Cola sin conexión** (`datos/cola_pendientes.dart`): `ClienteApi.publicar(..., sinConexion:
  Superposicion(...))` encola si no hay red. La superposición hace que lo pendiente se vea en su
  lista con `_pendiente`, y se sincroniza en orden al volver la red. La app genera los UUID v7
  (`core/identificadores.dart`) y el backend acepta `id` opcional e idempotente en las altas de
  compras, gastos e ingresos (responde 409 `identificador_en_uso` si es de otro usuario).

## Qué hace la app (funciones)

Pestañas actuales (cambian en la fase 4): **Mes**, **Diario**, **Transporte**, **Deudas**,
**Ahorro**, **Gráficas**. Desde el menú ⋮ del inicio: **Mis cuentas y efectivo**, **Mi sueldo**,
gastos fijos, cerrar el mes y **Mi cuenta**.

- **Mes**: sueldo base, ingresos extra, gastos fijos con estado (pendiente/parcial/pagado),
  disponible hoy y saldo al cerrar. El mes presupuestal va **del 28 al 27**.
- **Diario**: compras del día a día por medio (efectivo, débito, crédito). Lo cargado a una
  tarjeta de crédito pesa en el mes en que vence su corte. Captura por notificaciones y SMS
  (`docs/CAPTURA-DE-PAGOS.md`), poco fiable en la práctica.
- **Deudas** con abonos, y **créditos** con cuadro de amortización y simulador de abonos.
- **Transporte**: calendario con festivos colombianos. El usuario ya no lo usa; pasará a módulo
  opcional.
- **Mis cuentas**: saldo real de cada banco, billetera y efectivo, comparado con el disponible.
- **Mi sueldo**: ingreso en dólares, TRM oficial automática, ventana de pago en días hábiles y
  «Ya me llegó».

## Pendiente y mejoras sugeridas

**Datos**: ver `CLAUDE.local.md` (privado).

**Errores conocidos** (se arreglan en el rediseño)
- **La deuda total del resumen está mal**: «Deuda», «Patrimonio» y «Debes en total» solo suman
  las deudas informales. `ServicioResumen` usa `deudas.saldoTotal` y no suma
  `CreditoRepository.pendienteTotal` ni la tarjeta (fase 6, o antes si se pide).
- La curva «Mes a mes» de Gráficas baja de cero por la interpolación (fase 7).

**App**
- El **sueldo base de los meses no se recalcula solo** cuando cambia la TRM (fase 8).
- No hay **cuentas por cobrar** ni **transferencias entre cuentas propias** (en el plan).
- Los saldos de **Mis cuentas** se anotan a mano.
- Lo apuntado sin conexión no mueve el resumen del mes hasta que se sube.
- Del ROADMAP: volcado semanal de la base a S3, recordatorios de vencimientos, exportar a
  CSV/PDF y clave propia de firma para Android.

**Entorno**
- La cuenta de AWS está en el Free Plan por créditos y caduca hacia **diciembre de 2026**.
  Hay que decidir a dónde mover la API antes de esa fecha.
- Las pruebas del sueldo (`CalculadoraSueldoTest`, `SueldoEnDolaresTest`) usan como ejemplo un
  caso real: conviene anonimizarlas. **Nunca** poner cifras reales del usuario en código, pruebas
  ni commits: el repositorio es público (el clasificador de permisos ya bloqueó un push por eso).
- `docs/sueldo-falabella-2026-10.md` y `app/ios/` están sin versionar y no se usan.
- `app/.metadata` tiene un cambio local de Flutter sin versionar; no afecta.

## Datos y sincronización

Las convenciones para cuadrar la base con los bancos y la situación registrada son personales y
no van en el repositorio (que es público): están en `CLAUDE.local.md`, sin versionar, y en la
memoria del proyecto.
