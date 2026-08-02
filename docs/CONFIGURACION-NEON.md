# Configuración de PostgreSQL en Neon

Guía para crear la base de datos de producción. **No hace falta hasta la fase de despliegue**:
el desarrollo local usa un PostgreSQL instalado con Homebrew.

## Límites del plan gratuito

| Recurso | Límite | ¿Alcanza? |
|---|---|---|
| Almacenamiento | 0.5 GB por proyecto | Sí. El modelo completo con 10 años de histórico no llega a 50 MB |
| Cómputo | 100 CU-horas al mes | Sí. Con autosuspend, el uso previsto ronda las 6 CU-horas |
| Transferencia de red | 5 GB al mes por proyecto | Sí. Las respuestas de la API son JSON de pocos KB |
| Ramas | 10 por proyecto | Sí. Se usará una para producción y otra para pruebas |
| Proyectos | 100 | Sí |

El plan gratuito **no expira**. La base se suspende sola tras 5 minutos sin actividad y solo
consume cómputo mientras está despierta.

## Pasos en la consola de Neon

### 1. Crear el proyecto

En [console.neon.tech](https://console.neon.tech) → **New Project**:

| Campo | Valor | Por qué |
|---|---|---|
| **Project name** | `calculadora-gastos` | — |
| **Postgres version** | `17` | Es la versión que se usa en desarrollo local |
| **Cloud provider** | `AWS` | — |
| **Region** | `AWS US East (N. Virginia)` | **Importante**: es la región de Lambda (`us-east-1`). Elegir otra añadiría latencia en cada consulta |
| **Database name** | `gastos` | — |

### 2. Revisar la configuración del cómputo

En **Settings → Compute**:

| Ajuste | Valor recomendado |
|---|---|
| **Autosuspend delay** | 5 minutos (el valor por defecto) |
| **Compute size** | 0.25 CU mínimo, 1 CU máximo |

Subir el mínimo por encima de 0.25 CU consumiría la cuota mensual cuatro veces más rápido sin
aportar nada con este volumen de datos.

### 3. Copiar la cadena de conexión

En **Dashboard → Connection Details**, activa la casilla **Connection pooling** y copia la
cadena. Debe tener `-pooler` en el nombre del host:

```
postgresql://gastos_owner:CONTRASEÑA@ep-algo-123456-pooler.us-east-1.aws.neon.tech/gastos?sslmode=require
```

> **Usa siempre la variante con `-pooler`.** Lambda crea una instancia nueva por cada petición
> concurrente, y cada una abriría sus propias conexiones. Sin el *pooler* (PgBouncer), se agota
> el límite de conexiones de PostgreSQL en cuanto hay algo de concurrencia.
>
> `sslmode=require` tampoco es opcional: el tráfico viaja por internet, fuera de AWS.

### 4. Entregar la cadena de forma segura

La cadena contiene la contraseña, así que **no debe acabar en el repositorio**. Guárdala en un
archivo local, que ya está excluido por `.gitignore`:

```bash
# En la raíz del proyecto
cat > .env.neon <<'EOF'
DB_URL=jdbc:postgresql://ep-algo-123456-pooler.us-east-1.aws.neon.tech/gastos?sslmode=require
DB_USER=gastos_owner
DB_PASSWORD=la-contraseña-que-copiaste
EOF
```

Fíjate en que el prefijo cambia de `postgresql://` a **`jdbc:postgresql://`** y en que el
usuario y la contraseña van aparte, no dentro de la URL.

En el despliegue, estos valores se guardan en **SSM Parameter Store** como `SecureString` y
Lambda los lee al arrancar. Nunca se escriben en el código ni en variables de entorno del
repositorio.

## Comprobar la conexión

```bash
psql "postgresql://gastos_owner:CONTRASEÑA@ep-algo-123456-pooler.us-east-1.aws.neon.tech/gastos?sslmode=require" -c "SELECT version();"
```

## Aplicar el esquema

Flyway ejecuta las migraciones automáticamente al arrancar la aplicación. Para aplicarlas a
mano:

```bash
cd backend
DB_URL=... DB_USER=... DB_PASSWORD=... ./gradlew flywayMigrate
```

## Sobre el arranque en frío

Una base suspendida tarda unos cientos de milisegundos en despertar, y eso se suma al arranque
en frío de Lambda. La primera petición del día puede tardar cerca de un segundo; las
siguientes, milisegundos. El caché local del cliente hace que esa espera no se note al abrir la
aplicación.

## Respaldos

Neon conserva un historial de 24 horas en el plan gratuito, que permite restaurar a un instante
concreto. Es poco margen para datos financieros, así que se complementa con un volcado semanal
a S3 (`pg_dump`), previsto en la fase 6.

## Si algún día hubiera que salir de Neon

El esquema es PostgreSQL estándar, sin extensiones propietarias. Migrar a RDS, Supabase o un
servidor propio es un `pg_dump` seguido de un `pg_restore` y cambiar un parámetro en SSM. Es la
mitigación deliberada del riesgo descrito en el [ADR 0003](adr/0003-postgresql-neon.md).
