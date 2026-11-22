# Estado de la aplicación

Actualizado el **22 de noviembre de 2026**. Este documento resume cómo está todo y qué
falta, para retomar el trabajo sin tener que reconstruirlo.

## Versiones en uso

| Pieza | Versión | Dónde |
|---|---|---|
| App (teléfono, Mac, web) | **1.10.0+17** | APK instalado por cable · `/Applications/Mis gastos.app` · gastos.axchisan.com |
| Backend | commit `8e4363b` | Lambda `calculadora-gastos-api`, alias `live` |
| Esquema de base de datos | migración **V8** | Neon, proyecto de la Calculadora |
| Pruebas | backend **271**, app **87** | todas en verde |

## Qué hace la app

Secciones (pestañas): **Mes**, **Diario**, **Transporte**, **Deudas**, **Ahorro**, **Gráficas**.
Desde el menú ⋮ del inicio: **Mis cuentas y efectivo**, **Mi sueldo**, gastos fijos, cerrar
el mes y **Mi cuenta**.

- **Mes**: sueldo base, ingresos extra, gastos fijos con estado (pendiente/parcial/pagado),
  disponible hoy y saldo al cerrar. El mes presupuestal va **del 28 al 27**.
- **Diario**: compras del día a día por medio (efectivo, débito, crédito). Lo cargado a una
  tarjeta de crédito pesa en el mes en que vence su corte. El teléfono captura solas las
  compras desde las notificaciones y los SMS del banco (`docs/CAPTURA-DE-PAGOS.md`).
- **Deudas** con abonos, y **créditos** con cuadro de amortización y simulador de abonos.
- **Transporte**: calendario con festivos colombianos, o un presupuesto fijado a mano.
- **Mis cuentas** (v1.9.0): saldo real de cada banco, billetera y del efectivo. Lo compara
  con el disponible del mes en curso y dice si cuadra o cuánto falta por registrar. También
  aparece como tarjeta en el inicio.
- **Mi sueldo** (v1.9.0 y v1.10.0): ingreso mensual en dólares. Proyecta cada pago con el
  periodo que cubre, los dólares exactos (prorrateo por días), los pesos estimados con la
  **TRM oficial del día** (datos.gov.co, se actualiza sola) y la ventana de días hábiles en
  que llega, sin contar festivos. Compara transferencia directa con PayPal. «Ya me llegó»
  guarda lo que de verdad entró, calcula la tasa efectiva y lo pone como sueldo del mes.

## Trabajo del 13 al 16 de noviembre de 2026

1. **Sincronización de los datos de producción** con los extractos bancarios, hasta el
   13 nov.
2. **Mis cuentas** (migración V7, tabla `accounts`).
3. **Mi sueldo** (V7, `income_sources`; cálculo en `backend/.../sueldo/CalculadoraSueldo`).
4. **TRM automática y pagos recibidos** (V8: `income_sources.trm_automatica`,
   `income_payments`; cliente en `sueldo/ClienteTrm`).
5. Arreglos de entorno: Flutter fijado a 3.44.8 en la CI de la web, macOS 12 como mínimo
   para Xcode 26, `dart format` en la CI, JDK 17 para Gradle y Flutter.

## Pendiente y mejoras sugeridas

**Datos**: ver `CLAUDE.local.md` (privado).

**App**
- El **sueldo base de los meses no se recalcula solo** cuando cambia la TRM: hay que pulsar
  «Poner estos pagos como sueldo de cada mes».
- No hay **cuentas por cobrar** (lo que otros le deben al usuario). Hoy se anota en las notas
  del mes.
- Las **transferencias entre cuentas propias** no existen como concepto: se omiten a mano en
  la sincronización.
- Los saldos de **Mis cuentas** se anotan a mano; no se mueven con los gastos registrados.
- Del ROADMAP: duplicar el motor de cálculo en Dart, gráfica de metas de ahorro, volcado
  semanal de la base a S3, recordatorios de vencimientos, exportar a CSV/PDF y clave propia
  de firma para Android.

**Entorno**
- `docs/sueldo-falabella-2026-10.md` está sin versionar y es obsoleto.
- `app/ios/` está sin versionar (se generó y no se usa).
- La cuenta de AWS está en el Free Plan por créditos y caduca hacia **diciembre de 2026**.
  Hay que decidir a dónde mover la API antes de esa fecha.
- Las pruebas del sueldo (`CalculadoraSueldoTest`, `SueldoEnDolaresTest`) usan como ejemplo
  un caso real: conviene anonimizarlas.

## Datos y sincronización

Las convenciones para cuadrar la base con los bancos y la situación registrada son
personales y no van en el repositorio (que es público): están en `CLAUDE.local.md`, sin
versionar, y en la memoria del proyecto.
