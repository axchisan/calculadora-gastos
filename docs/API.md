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

## Pendiente de implementar

Los endpoints de meses, gastos, deudas, ahorro y transporte se documentarán aquí conforme se
construyan. Ver [ROADMAP.md](ROADMAP.md).
