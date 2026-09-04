# API REST

Base: `https://api.axchisan.com` · en desarrollo `http://localhost:8080`

Documentación interactiva (OpenAPI) en `/docs`.

## Autenticación

Todos los endpoints salvo los marcados como públicos requieren la cabecera:

```
Authorization: Bearer <accessToken>
```

El **access token** dura 15 minutos. Cuando caduca, se renueva con el **refresh token**, que
dura 30 días y **rota en cada uso**: la respuesta de `/refresh` trae uno nuevo y el anterior
deja de servir.

> **El cliente debe guardar siempre el último refresh token recibido.** Si reenvía uno ya
> consumido, el servidor lo interpreta como un token robado y revoca la sesión completa.

### `GET /api/auth/registro-abierto` · público

```json
{ "abierto": false }
```

Indica si se admiten cuentas nuevas. La aplicación lo consulta antes de mostrar la pantalla de
acceso para ocultar la opción de crear cuenta en lugar de ofrecerla y que acabe en un error.

### `POST /api/auth/registro` · público

```json
{ "email": "duvan@axchisan.com", "password": "mínimo 8 caracteres", "nombre": "Duvan" }
```

**201 Created**

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "refreshToken": "N2QxYzRlNmY4YTBiM2Q1...",
  "expiraEn": 900,
  "usuario": {
    "id": "0198f2c1-...",
    "email": "duvan@axchisan.com",
    "nombre": "Duvan",
    "moneda": "COP",
    "zonaHoraria": "America/Bogota"
  }
}
```

| Error | Estado | Cuándo |
|---|---|---|
| `datos_invalidos` | 400 | Correo mal formado o contraseña de menos de 8 caracteres |
| `email_ya_registrado` | 409 | Ya existe una cuenta con ese correo |
| `registro_cerrado` | 403 | Ya existe una cuenta y no se admiten más |

> **El registro se cierra solo.** Al ser una aplicación de uso personal, queda abierto mientras
> la base no tenga ninguna cuenta —para poder crear la primera— y se cierra en cuanto hay una.
> No hace falta acordarse de desactivarlo. La propiedad `app.registro.abierto` permite
> reabrirlo si alguna vez hiciera falta.

El correo se normaliza a minúsculas: `Duvan@Axchisan.com` y `duvan@axchisan.com` son la misma
cuenta.

### `POST /api/auth/login` · público

```json
{ "email": "duvan@axchisan.com", "password": "..." }
```

**200 OK** — misma estructura que el registro.

| Error | Estado | Cuándo |
|---|---|---|
| `credenciales_invalidas` | 401 | Correo o contraseña incorrectos |
| `demasiados_intentos` | 429 | 5 intentos fallidos; incluye cabecera `Retry-After` |

La respuesta es **idéntica** tanto si el correo no existe como si la contraseña es incorrecta,
para no revelar qué cuentas están registradas.

### `POST /api/auth/refresh` · público

```json
{ "refreshToken": "..." }
```

**200 OK** — nuevo par de tokens. El refresh token enviado queda invalidado.

| Error | Estado | Cuándo |
|---|---|---|
| `token_invalido` | 401 | No existe, caducó, fue revocado o **ya se había usado** |

### `POST /api/auth/logout` · público

```json
{ "refreshToken": "..." }
```

**204 No Content**. Revoca la sesión. Es público a propósito: permite cerrar sesión aunque el
access token ya haya caducado.

### `GET /api/auth/yo`

**200 OK**

```json
{
  "id": "0198f2c1-...",
  "email": "duvan@axchisan.com",
  "nombre": "Duvan",
  "moneda": "COP",
  "zonaHoraria": "America/Bogota"
}
```

### `PATCH /api/auth/password`

```json
{ "passwordActual": "…", "passwordNueva": "mínimo 8 caracteres" }
```

Devuelve una sesión nueva. **Revoca todas las demás**: si la contraseña se cambió por sospecha
de robo, dejar vivas las otras sesiones no serviría de nada.

Exige la contraseña actual para que a quien encuentre una sesión abierta en un dispositivo
desatendido no le baste con cambiarla para quedarse con la cuenta.

### `PATCH /api/auth/email`

```json
{ "password": "…", "emailNuevo": "nuevo@axchisan.com" }
```

También pide la contraseña, porque el correo es la otra mitad de las credenciales. Revoca el
resto de sesiones igual que el cambio de contraseña.

### `PATCH /api/auth/nombre`

```json
{ "nombre": "Duvan Andrés" }
```

No exige contraseña: el nombre no da acceso a nada.

### `GET /api/salud` · público

```json
{ "estado": "ok", "instante": "2026-08-02T11:31:03-05:00" }
```

## Formato de errores

```json
{ "error": "codigo_legible", "mensaje": "Descripción para mostrar al usuario" }
```

Los errores de validación añaden el detalle por campo:

```json
{
  "error": "datos_invalidos",
  "mensaje": "Revisa los datos enviados",
  "campos": { "email": "El correo no tiene un formato válido" }
}
```

## Aislamiento entre usuarios

El identificador de usuario se toma **siempre del token**, nunca de la URL ni del cuerpo de la
petición. No existe ningún endpoint que acepte un identificador de usuario como parámetro, así
que no hay forma de consultar datos ajenos manipulando una petición.

## Meses

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/meses` | Lista los meses, del más reciente al más antiguo |
| `POST` | `/api/meses` | Crea un mes copiando los gastos fijos y precalculando el transporte |
| `GET` | `/api/meses/{id}` | Devuelve un mes |
| `GET` | `/api/meses/periodo/{anio}/{mes}` | Busca por periodo |
| `GET` | `/api/meses/{id}/resumen` | **Estado financiero completo** |
| `GET` | `/api/meses/evolucion?anio=&mes=` | Serie histórica para las gráficas |
| `PATCH` | `/api/meses/{id}` | Cambia el sueldo o las notas |
| `POST` | `/api/meses/{id}/cerrar` · `/reabrir` | Congela o reabre el mes |
| `DELETE` | `/api/meses/{id}` | Elimina el mes y su contenido |

Crear un mes hace tres cosas de una vez: copia las plantillas activas como gastos, hereda del
mes anterior el sueldo y la configuración de transporte, y genera el calendario del mes con los
festivos ya descontados.

### El resumen mensual

```json
{
  "periodo": "2026-08",
  "ingresoBase": 3174000,
  "ingresoTotal": 3174000,
  "ingresoProyectado": 3174000,
  "gastoTotal": 1132000,
  "gastoPagado": 600000,
  "gastoPendiente": 532000,
  "abonosDeuda": 0,
  "aporteAhorro": 0,
  "disponibleHoy": 2574000,
  "saldoProyectado": 2042000,
  "deudaTotal": 0,
  "ahorroTotal": 0,
  "patrimonioNeto": 0,
  "comprasDelMes": 189640,
  "comprasInmediatas": 89640,
  "comprasACredito": 100000,
  "cortesTarjetaPendientes": 0,
  "cortesTarjetaPagados": 0,
  "porCategoria": [
    { "categoria": "VIVIENDA", "total": 600000, "porcentaje": 53.00 },
    { "categoria": "TRANSPORTE", "total": 142000, "porcentaje": 12.54 }
  ]
}
```

La distinción entre **`disponibleHoy`** y **`saldoProyectado`** es la métrica central:

- `disponibleHoy` = ingresos cobrados − todo lo que ya salió del bolsillo. Responde a «¿cuánto
  tengo ahora mismo?».
- `saldoProyectado` = ingresos previstos − todo lo que tiene destino este mes. Responde a
  «¿cómo cierra el mes?».

Ver solo el primero da la ilusión de tener dinero que en realidad ya está comprometido.

Lo que sale del bolsillo son cinco cosas, no dos: gastos pagados, abonos a deudas, aportes al
ahorro, compras del día a día pagadas en el acto y cortes de tarjeta ya saldados.

**`comprasACredito` es la excepción y no entra en ninguna de esas cifras.** Se compró este mes
pero el dinero sale cuando venza el corte, uno o dos meses después. Aparece en el resumen para
poder avisar, no para sumarlo.

### Ingresos adicionales

| Método | Ruta |
|---|---|
| `GET` · `POST` | `/api/meses/{id}/ingresos` |
| `PATCH` | `/api/meses/ingresos/{id}/recibido?recibido=true` |
| `DELETE` | `/api/meses/ingresos/{id}` |

Un ingreso no cobrado suma a `ingresoProyectado` pero **no** a `ingresoTotal`.

## Gastos

| Método | Ruta | Descripción |
|---|---|---|
| `GET` · `POST` | `/api/meses/{mesId}/gastos` | Lista o añade gastos |
| `PATCH` | `/api/gastos/{id}` | Modifica un gasto |
| `POST` | `/api/gastos/{id}/pagar` | Marca como pagado por completo |
| `POST` | `/api/gastos/{id}/pendiente` | Deshace el pago |
| `POST` | `/api/gastos/{id}/abonar` | Abono parcial |
| `DELETE` | `/api/gastos/{id}` | Elimina el gasto |

Cada gasto trae un campo **`editable`**. Los de origen `TRANSPORTE` y `DEUDA` los mantiene el
sistema y devuelven `409 gasto_no_editable` si se intentan modificar: el primero se cambia desde
el calendario y el segundo desde el módulo de deudas. Marcarlos como pagados sí está permitido.

| Error | Estado |
|---|---|
| `no_encontrado` | 404 |
| `mes_cerrado` | 409 |
| `gasto_no_editable` | 409 |
| `peticion_invalida` (abono mayor al saldo) | 400 |

## Transporte

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/meses/{mesId}/transporte` | Resumen con el detalle día a día |
| `GET` | `/api/meses/{mesId}/transporte/configuracion` | Tarifa, días laborales y de karate |
| `GET` | `/api/meses/{mesId}/transporte/escenarios` | Proyecciones optimista, esperada y pesimista |
| `PATCH` | `/api/meses/{mesId}/transporte/configuracion` | Cambia los parámetros y recalcula |
| `PATCH` | `/api/meses/{mesId}/transporte/presupuesto` | Fija a mano lo que costará el mes; con `null` vuelve a mandar el calendario |
| `POST` | `/api/meses/{mesId}/transporte/regenerar` | Descarta los ajustes y propone de nuevo |
| `PATCH` | `.../dias/{diaId}/tipo` | Reclasifica un día |
| `PATCH` | `.../dias/{diaId}/pasajes` | Fija los pasajes a mano |
| `PATCH` | `.../dias/{diaId}/confirmar` | Marca el día como ya transcurrido |

**Todas las operaciones de escritura devuelven el resumen recalculado**, para que el cliente
actualice la pantalla con una sola petición.

Cambiar la tarifa **no** descarta los ajustes del calendario. Para reclasificar los días hay que
pasar `"regenerarClasificacion": true` o llamar a `/regenerar`.

## Compras del día a día

Los gastos sueltos: el agua, el chocorramo, la comisión del cajero. Van aparte de `/api/gastos`
porque su ciclo de vida es distinto: una compra ya ocurrió y ya se pagó. No tiene estado
pendiente ni abonos parciales. Lo único que varía es **de dónde salió el dinero**.

| Método | Ruta | Descripción |
|---|---|---|
| `GET` · `POST` | `/api/meses/{id}/compras` | Compras del mes con sus totales, y registro |
| `PATCH` · `DELETE` | `/api/compras/{id}` | Modifica o elimina |

```json
{
  "descripcion": "Perfume",
  "monto": 100000,
  "categoria": "CUIDADO_PERSONAL",
  "fecha": "2026-08-14",
  "medio": "CREDITO",
  "tarjetaId": "01a0..."
}
```

`medio` es `EFECTIVO`, `DEBITO` o `CREDITO`. Con crédito la tarjeta es obligatoria: sin ella no
habría forma de saber cuándo vence.

La fecha tiene que caer dentro del mes en que se registra. Sin esa comprobación sería fácil
apuntar en agosto algo comprado en septiembre, y el mes de pago saldría mal en silencio.

La respuesta añade dos campos calculados: `periodoPago` (`aaaa-mm`, el mes del que sale el
dinero) y `vencimiento` (la fecha exacta).

## Tarjetas

| Método | Ruta | Descripción |
|---|---|---|
| `GET` · `POST` | `/api/tarjetas` | Lista o registra |
| `PATCH` · `DELETE` | `/api/tarjetas/{id}` | Modifica, o archiva si ya tiene compras |

Una tarjeta de crédito necesita `diaCorte` y `diaPago`, ambos entre 1 y 28 para que el día
exista en todos los meses. El tipo no se puede cambiar después: las compras ya registradas
calcularon su mes de pago con ese ciclo.

### El ciclo de facturación

Con corte el 15 y pago el 4:

| Compra | Corte | Se paga |
|---|---|---|
| 14 de agosto | 15 de agosto | 4 de septiembre |
| 15 de agosto | 15 de agosto | 4 de septiembre |
| 16 de agosto | 15 de septiembre | 4 de **octubre** |

Dos días de diferencia desplazan el pago un mes entero. Es exactamente el cálculo que sale mal
cuando se hace de memoria, y la razón de que lo haga el servidor en vez de pedir el mes.

El mes de pago se **guarda** con la compra en lugar de recalcularse al vuelo. Así se puede
sumar en una consulta, y sobre todo congela el resultado: si algún día cambia el día de corte,
las compras ya hechas conservan el mes en el que realmente se pagaron.

### Cortes

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/cortes/{aaaa-mm}` | Lo que vence ese mes, por tarjeta |
| `PUT` | `/api/cortes/{aaaa-mm}/tarjetas/{id}` | Marca el corte entero como pagado |

Un corte reúne compras de meses distintos: lo que vence en octubre son las del 16 de agosto en
adelante y hasta el 15 de septiembre. Por eso no se puede sacar mirando un solo mes.

Se salda entero, no compra por compra: el banco tampoco cobra por partes.

## Deudas

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/deudas?soloActivas=false` | Lista las deudas |
| `GET` | `/api/deudas?periodo=2026-08` | Solo las que tenían que ver con ese mes |
| `POST` | `/api/deudas` | Registra una deuda |
| `GET` · `PATCH` · `DELETE` | `/api/deudas/{id}` | Consulta, modifica o elimina |
| `GET` · `POST` | `/api/deudas/{id}/abonos` | Historial y registro de abonos |
| `DELETE` | `/api/deudas/abonos/{id}` | Elimina un abono y devuelve el saldo |

Al abonar, el saldo baja; al llegar a cero la deuda se marca inactiva y deja de contar en
`deudaTotal`. Un abono mayor al saldo se rechaza con `400`.

Los abonos **no** generan un gasto en el mes: se contabilizan aparte en `abonosDeuda` del
resumen. Crear además un gasto los contaría dos veces.

### Deudas de un mes

Una deuda no pertenece a un mes: se contrae un día y se arrastra hasta saldarla. Pero listarlas
todas siempre hacía que las de agosto, ya pagadas, siguieran apareciendo en septiembre como si
aún se debieran, mezcladas con las de verdad.

Con `?periodo=aaaa-mm` se devuelven solo las que tenían algo que ver con ese mes. Una deuda
cuenta si ya existía al terminarlo y, además, se cumple una de dos:

- seguía debiéndose a esas alturas, o
- se abonó algo durante ese mes.

Lo segundo es lo que conserva en agosto las deudas que se saldaron en agosto: el mes en que se
pagaron es justamente donde tiene sentido verlas.

Con el filtro activo, `saldo`, `porcentajePagado` y `activa` se reconstruyen **al cierre de ese
mes**, no a día de hoy. Al consultar agosto interesa lo que se debía en agosto; mostrar el
saldo actual haría que una deuda saldada apareciera en cero en el mes en que aún se debía
entera.

## Ahorro

| Método | Ruta | Descripción |
|---|---|---|
| `GET` · `POST` | `/api/ahorro/metas` | Lista o crea metas |
| `PATCH` · `DELETE` | `/api/ahorro/metas/{id}` | Modifica o elimina |
| `GET` · `POST` | `/api/ahorro/metas/{id}/movimientos` | Aportes y retiros |
| `DELETE` | `/api/ahorro/movimientos/{id}` | Elimina y revierte el saldo |
| `GET` | `/api/ahorro/distribucion/{mesId}` | **Sugiere el reparto del disponible** |

Tipos de asignación:

| Tipo | Base del cálculo |
|---|---|
| `MONTO_FIJO` | Cantidad fija |
| `PORCENTAJE_INGRESO` | Porcentaje del ingreso del mes |
| `PORCENTAJE_SOBRANTE` | Porcentaje de lo que queda tras gastos y deudas |

Las de tipo `PORCENTAJE_SOBRANTE` se aplican **en cascada por prioridad**: dos metas al 50% del
sobrante se llevan el 50% y luego el 50% del resto (el 25%), no el 100% entre las dos.

`/distribucion` es una **sugerencia y no mueve dinero**; para materializarla hay que registrar
los movimientos.

## Festivos

| Método | Ruta |
|---|---|
| `GET` | `/api/festivos/{anio}` |
| `GET` | `/api/festivos/{anio}/{mes}` |

```json
[
  {
    "fecha": "2026-08-17",
    "diaSemana": "MONDAY",
    "nombre": "Asunción de la Virgen",
    "tipo": "TRASLADADO",
    "fechaOriginal": "2026-08-15",
    "trasladado": true
  }
]
```

Devuelve **18 celebraciones**, que pueden ocupar solo 17 días cuando dos coinciden — ver
[FESTIVOS-Y-TRANSPORTE.md](FESTIVOS-Y-TRANSPORTE.md).
