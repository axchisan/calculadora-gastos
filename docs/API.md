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
  "porCategoria": [
    { "categoria": "VIVIENDA", "total": 600000, "porcentaje": 53.00 },
    { "categoria": "TRANSPORTE", "total": 142000, "porcentaje": 12.54 }
  ]
}
```

La distinción entre **`disponibleHoy`** y **`saldoProyectado`** es la métrica central:

- `disponibleHoy` = ingresos cobrados − gastos **ya pagados** − abonos − ahorro. Responde a
  «¿cuánto tengo ahora mismo?».
- `saldoProyectado` = ingresos previstos − gastos **totales** − abonos − ahorro. Responde a
  «¿cómo cierra el mes?».

Ver solo el primero da la ilusión de tener dinero que en realidad ya está comprometido.

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
| `POST` | `/api/meses/{mesId}/transporte/regenerar` | Descarta los ajustes y propone de nuevo |
| `PATCH` | `.../dias/{diaId}/tipo` | Reclasifica un día |
| `PATCH` | `.../dias/{diaId}/pasajes` | Fija los pasajes a mano |
| `PATCH` | `.../dias/{diaId}/confirmar` | Marca el día como ya transcurrido |

**Todas las operaciones de escritura devuelven el resumen recalculado**, para que el cliente
actualice la pantalla con una sola petición.

Cambiar la tarifa **no** descarta los ajustes del calendario. Para reclasificar los días hay que
pasar `"regenerarClasificacion": true` o llamar a `/regenerar`.

## Deudas

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/deudas?soloActivas=false` | Lista las deudas |
| `POST` | `/api/deudas` | Registra una deuda |
| `GET` · `PATCH` · `DELETE` | `/api/deudas/{id}` | Consulta, modifica o elimina |
| `GET` · `POST` | `/api/deudas/{id}/abonos` | Historial y registro de abonos |
| `DELETE` | `/api/deudas/abonos/{id}` | Elimina un abono y devuelve el saldo |

Al abonar, el saldo baja; al llegar a cero la deuda se marca inactiva y deja de contar en
`deudaTotal`. Un abono mayor al saldo se rechaza con `400`.

Los abonos **no** generan un gasto en el mes: se contabilizan aparte en `abonosDeuda` del
resumen. Crear además un gasto los contaría dos veces.

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
