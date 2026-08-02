# 0004 — Autenticación JWT propia con Spring Security

- **Estado**: Aceptada
- **Fecha**: 2026-08-02

## Contexto

La aplicación maneja información financiera personal y debe estar protegida en los tres
clientes. El número de usuarios previsto es muy bajo (uso personal, quizá algún familiar).

## Decisión

Implementar autenticación con **JSON Web Tokens sobre Spring Security**:

| Elemento | Definición |
|---|---|
| Access token | JWT firmado HS256, vigencia 15 minutos, en `Authorization: Bearer` |
| Refresh token | Opaco, vigencia 30 días, **rotativo** en cada uso |
| Almacenamiento del refresh | Hash SHA-256 en `refresh_tokens`; nunca en claro |
| Contraseñas | BCrypt con factor de coste 12 |
| Secreto de firma | SSM Parameter Store (`SecureString`), tier estándar gratuito |

En el cliente, los tokens se guardan en el almacenamiento seguro de cada plataforma
(`flutter_secure_storage`: Keychain en macOS, Keystore en Android; en web, memoria más
cookie `HttpOnly` para el refresh).

La rotación de refresh tokens permite **detectar reutilización**: si llega un refresh token
ya consumido, se revoca toda la familia de tokens de esa sesión, porque indica que fue
robado.

## Alternativas consideradas

**AWS Cognito.** Ofrece 10.000 usuarios activos al mes gratis y resuelve MFA, recuperación de
contraseña y login social sin escribir código. Se descarta porque introduce infraestructura y
un modelo de configuración considerables para un puñado de usuarios, acopla la aplicación a
AWS y complica el desarrollo local. La funcionalidad que aporta de más no se necesita hoy.

**Sesiones con cookies del lado del servidor.** Encajan mal con Lambda, que no mantiene
estado entre invocaciones, y complicarían los clientes móviles.

**Auth0 / Clerk.** Free tiers adecuados, pero suman otro proveedor externo al que ya se añade
con Neon.

## Consecuencias

**Positivas**

- Sin costo ni infraestructura adicional.
- Control total sobre el flujo, fácil de depurar en local.
- Es el mismo patrón que se usa habitualmente en Spring Boot empresarial.

**Negativas**

- **La seguridad de la implementación es responsabilidad propia**: expiración, rotación,
  revocación y almacenamiento seguro deben implementarse y probarse con cuidado.
- MFA, recuperación de contraseña por correo y login social habría que construirlos si algún
  día se necesitan.
- Si el secreto de firma se filtra, todos los tokens quedan comprometidos; debe poder rotarse
  (el `kid` en la cabecera del JWT permite convivencia de claves durante la rotación).

## Requisitos de implementación

1. Los endpoints `/api/auth/**` quedan fuera del filtro de autenticación; todo lo demás lo
   exige.
2. Todas las consultas filtran por el `user_id` del token: ningún endpoint acepta un
   identificador de usuario como parámetro.
3. CORS restringido a `https://gastos.axchisan.com` y `http://localhost` para desarrollo.
4. Limitación de intentos de inicio de sesión (por correo y por IP) para frenar fuerza bruta.
5. Respuestas de login genéricas ante credenciales inválidas, sin revelar si el correo existe.
