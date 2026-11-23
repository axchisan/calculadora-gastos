# Registro automático de movimientos — planteamiento

Noviembre de 2026. Sustituye el enfoque de [CAPTURA-DE-PAGOS.md](CAPTURA-DE-PAGOS.md) (solo
notificaciones de Android), que en el uso real no resultó fiable.

## Qué se sabe

**No hay vía oficial.** Ningún banco colombiano ofrece hoy una API para que una persona lea sus
propios movimientos. El Open Finance obligatorio (Decreto 0368 de 2026) solo dará datos a
empresas inscritas ante la SFC, y su calendario apunta a 2028 o después. Los agregadores con
cobertura en Colombia (Belvo, Prometeo) son para empresas y cuestan desde unos 1.000 USD/mes.
Entrar automáticamente a la Sucursal Virtual choca con la Clave Dinámica y es zona gris legal.

**Lo que sí llega solo, medido con datos reales de dos meses (octubre y noviembre de 2026):**

| Fuente | Cobertura de los movimientos de la cuenta de ahorros | Llega | Esfuerzo del usuario |
|---|---|---|---|
| Correo de «Alertas y Notificaciones» | ≈40 % | En segundos | Ninguno |
| SMS de Bancolombia (85540, 85784, 85630; el 87400 para pagos con QR) | ≈42 % | En segundos | Ninguno |
| Correo + SMS | **≈63 %** (41 de 65; 15 solo por SMS, 14 solo por correo, 12 por ambos) | En segundos | Ninguno |
| PDF «Movimientos» de la app o la Sucursal Virtual | **100 %** (sin hora) | Cuando se descarga | Unos segundos a la semana |

- Bancolombia no avisa siempre por los dos canales: unas veces por correo, otras por SMS y otras
  por ambos, sin umbral de monto ni criterio visible.
- **Nunca avisa** las transferencias que entran desde Nequi (ni por correo ni por SMS), ni las
  transferencias entre cuentas propias; tampoco algunas compras y transferencias sueltas. En esta cuenta, lo que entra desde Nequi es la mayor parte de los ingresos.
- El texto del correo y el del SMS es el mismo («Bancolombia: Compraste $X en COMERCIO con tu
  T.Deb *NNNN, el dd/mm/aaaa a las hh:mm…»), con siete plantillas conocidas y tres formatos de
  importe (`$40,000` · `$2.000,00` · `$150000.00`).
- Nu avisa por correo los pagos con la Cuenta Nu, no las compras con la tarjeta. Banco de Bogotá
  envía comprobantes de transferencia. Nequi no envía correos de movimientos.

**Conclusión:** ninguna fuente basta sola. Correo y SMS dan el aviso en el momento, pero solo
del 63 %. El PDF tiene todo, pero solo cuando se descarga. La solución es combinarlas y
**conciliar**.

## Diseño

### Una bandeja de «movimientos detectados»

Todo lo que llega de fuera (correo, SMS, PDF y, si se quiere, notificaciones) se convierte en
un **movimiento detectado** y entra en una bandeja «Por revisar». Nada se guarda como gasto o
ingreso sin que el usuario lo vea: se **acepta** (con la categoría sugerida o cambiándola), se
**descarta** o se marca como **ya registrado**.

```
correo ─┐
SMS ────┼──▶ POST /api/detectados ──▶ parser por plantilla ──▶ deduplicación ──▶ reglas ──▶ «Por revisar»
PDF ────┘                                (LLM de respaldo)       (mismo mov.       (cuentas propias,   │
                                                                  por 2 canales)    contrapartes)       ▼
                                                                                       aceptar → compra / gasto / ingreso / abono
```

### Deduplicación (la pieza clave)

Un mismo movimiento puede llegar por correo hoy y por el PDF el domingo, y puede que ya se haya
apuntado a mano. Se considera el mismo movimiento si coinciden **cuenta, signo e importe
exacto**, con fecha a ±1 día (el PDF no trae hora y a veces registra al día siguiente). Antes de
sugerir algo se busca también entre lo ya registrado en el mes (compras, gastos, ingresos,
abonos), para no proponer lo que ya está.

### Reglas

- **Cuentas propias**: las transferencias entre cuentas del usuario (Bancolombia ↔ Nequi propio,
  a la llave propia) se descartan solas: no son ni gasto ni ingreso.
- **Contrapartes conocidas**: por teléfono, llave, número de cuenta o nombre del comercio → qué
  es (por ejemplo, «este Nequi es de mamá: ingreso de tipo Familia», «esta llave es la parte de
  una suscripción: gasto fijo X», «pagar a esta entidad es la cuota de la deuda Y»).
- Al aceptar o corregir una sugerencia se ofrece «Hacerlo siempre así», que crea la regla. Con el
  tiempo casi todo llega ya clasificado y se acepta en bloque.
- Las reglas viven en la base de datos del usuario, nunca en el código (el repositorio es
  público).

### Cómo entra cada fuente

| Fuente | Cómo | Notas |
|---|---|---|
| Correo | **Google Apps Script** en la cuenta de Gmail del usuario, con un disparador cada pocos minutos: busca los correos nuevos de los remitentes del banco, comprueba que vienen firmados (DKIM) y los envía a la API con un secreto propio. | Sin OAuth de Google en el backend (se evita que el token caduque a los 7 días en modo de pruebas). Etiqueta los correos procesados para no repetirlos. |
| SMS | La app de Android recibe los SMS de Bancolombia (85540, 85784, 85630, 87400) con un `BroadcastReceiver` de `SMS_RECEIVED` y lo envía a la API. | Más fiable que leer notificaciones: el sistema despierta la app para cada SMS aunque esté cerrada. Requiere el permiso de SMS (la app se instala por APK, fuera de Play Store). |
| PDF | Compartir el PDF «Movimientos» a la app desde el teléfono (menú Compartir de Android) o subirlo en la web o el Mac. El backend lo lee (PDFBox) y propone lo que falte. | Es la red de seguridad que lleva la cobertura al 100 %. Una vez por semana basta. Después, extractos de Nu y Nequi. |
| Notificaciones | La captura actual se mantiene como fuente opcional más. | Útil para Nequi y para las compras con la tarjeta de Nu. |

### Seguridad

- Ninguna credencial bancaria en ningún sitio: solo se leen avisos que el banco ya envía al
  usuario y documentos que él mismo descarga.
- La API de detectados exige un secreto por usuario (en la cabecera, con firma HMAC del cuerpo),
  distinto del token de sesión, que se puede revocar.
- Se guarda el texto crudo de cada aviso para poder reprocesarlo si cambia una plantilla, y se
  borra pasado un tiempo.

## Fases

| Fase | Qué | Resultado |
|---|---|---|
| **A** | Backend: tabla de movimientos detectados, parser de Bancolombia (correo, SMS y PDF) con pruebas por plantilla, deduplicación contra lo registrado y entre canales, reglas de cuentas propias, endpoints. | La base. Se prueba con textos inventados. |
| **B** | App: bandeja «Por revisar» en Movimientos (aceptar, cambiar, descartar, aceptar en bloque, «hacerlo siempre así») e importar el PDF (compartir en Android, subir en web y Mac). | Ya se puede conciliar a mano cada semana con el PDF: el 100 %. |
| **C** | Tiempo real: receptor de SMS en Android (con lectura del historial de SMS para empezar con datos) y Apps Script de Gmail. | El 63 % llega solo en el momento. |
| **D** | Más fuentes: correos y extracto de Nu, comprobantes de Banco de Bogotá, extracto de Nequi. | Cobertura de las demás cuentas. |
| **E** | Pulido: LLM de respaldo para avisos que no encajan en ninguna plantilla, sugerencia de categoría por el historial y aviso cuando una plantilla deja de reconocerse. | Mantenimiento. |

## Configuración de las alertas de Bancolombia

Revisado en la Sucursal Virtual Personas (Ajustes → Seguridad → Alertas y notificaciones) el 23 de
noviembre de 2026: el servicio solo se puede **activar o desactivar entero**. No hay opciones por
tipo de movimiento, canal ni monto mínimo, y la app Mi Bancolombia no tiene ese ajuste. Los avisos
van al correo y al celular de los datos de contacto. Por eso lo que no se avisa (lo que entra
desde Nequi, entre otros) solo se puede recuperar con el PDF.

## Fase A: lo construido

- `deteccion/LectorAvisosBancolombia`: once plantillas de avisos (el correo y el SMS usan el
  mismo texto). Importe, fecha y hora se leen aparte porque Bancolombia mezcla formatos dentro
  de una misma plantilla. Probado contra los 502 SMS reales de Bancolombia del teléfono: los 469
  que son movimientos se entienden todos, y los 33 restantes (códigos, rechazos, activar la
  tarjeta, publicidad) se ignoran.
- `deteccion/LectorExtractoBancolombia`: el PDF «Movimientos» con PDFBox. Las descripciones
  largas ocupan varios renglones, así que el texto se saca en el orden del documento y se corta
  por fechas. Con el extracto real de septiembre a noviembre: las 150 líneas, con la misma suma
  neta que otra herramienta de extracción.
- `ServicioDetectados` y `/api/detectados` (ver [API.md](API.md)): bandeja, cruce entre
  canales, cruce con lo ya registrado, reglas, intereses y retiros de cajero descartados solos.
- Los avisos entraban con el token de sesión; desde la fase C, el teléfono y Gmail usan una
  clave de ingesta propia (ver abajo).

## Fase B: lo construido

- **Bandeja «Por revisar»** (Movimientos → aviso «N movimientos por revisar», o el menú «Lo que
  llegó del banco»): cada movimiento se registra como compra, gasto, ingreso o abono a una
  deuda, se marca como ya apuntado o se descarta. «Hacerlo siempre así» guarda la regla, y lo
  que una regla ya sabe registrar se acepta en bloque.
- **Importar el PDF**: en Android, «Compartir» desde WhatsApp, Gmail o Archivos → «Mis gastos»
  (o «Abrir con»); en la web y el Mac, el botón de la bandeja abre el selector de archivos.
- **Desde cuándo**: solo desde el último cuadre (el día en que se anotó el saldo del banco
  principal). Lo anterior se cuadró a mano con otras convenciones y llenaría la bandeja.
- **Cuentas propias**: el extracto trae el nombre del titular; con él se crea sola una regla
  que descarta las transferencias a su nombre.
- Probado con una copia local de la base de producción y el extracto real: simulando un cuadre
  el 28 oct, de 40 movimientos 17 se reconocieron como ya apuntados, 5 transferencias propias y
  11 intereses se descartaron solos y quedaron 7 por revisar, que eran justo los que las
  convenciones registran distinto (apoyo de la familia en neto, préstamos).

## Fase C: lo construido

- **Claves de ingesta** (`/api/ingesta`): una por dispositivo, revocable, solo para enviar
  avisos; se guarda su huella. Se eligió una clave en cabecera sobre HTTPS en vez de firmar
  cada petición con HMAC: repetir un aviso no tiene efecto (la huella lo descarta) y la clave
  no da acceso a nada más.
- **SMS en Android** (`ReceptorSms`, `EnvioDeAvisos`): Android despierta la app con cada SMS;
  los de Bancolombia (85540, 85784, 85630, 87400 o texto que empieza por «Bancolombia») se
  envían al momento, y lo que no sale por falta de red queda en cola hasta el siguiente SMS o
  hasta abrir la app. Al activarlo se mandan los SMS del banco desde el último cuadre.
- **Gmail** (`lib/datos/script_gmail.dart`): un Apps Script en la cuenta del usuario revisa
  cada 5 minutos los correos de «Alertas y Notificaciones», exige que Gmail los haya
  verificado como firmados (DKIM) por `notificacionesbancolombia.com` y manda solo la frase
  del aviso, que es la misma del SMS. La app lo copia con la clave puesta.
- Todo se activa en Ajustes → Registro automático (también desde el engranaje de la bandeja).
- **Pendiente**: borrar el texto crudo de los avisos pasado un tiempo.
