# Plan de trabajo

Orden de construcción pensado para tener algo **usable cuanto antes** y para que cada fase
deje valor por sí sola, en lugar de construir toda la infraestructura antes de ver la primera
pantalla.

## Fase 0 — Fundamentos

- [x] Investigar el estado real del free tier de la cuenta AWS
- [x] Decidir arquitectura, autenticación, plataformas y estructura del repositorio
- [x] Documentar arquitectura, modelo de dominio, costos y decisiones (ADR)
- [x] Especificar el algoritmo de festivos colombianos y el motor de transporte
- [x] Esqueleto del backend (Spring Boot 3, Java 21, Gradle)
- [x] Esqueleto del cliente (Flutter, tres objetivos de compilación)
- [x] Repositorio en GitHub
- [ ] Integración continua

## Fase 1 — Backend: base

- [x] Migraciones Flyway con el esquema completo (13 tablas)
- [x] Registro, inicio de sesión, refresh con rotación y cierre de sesión
- [x] Filtro de seguridad, CORS y limitación de intentos
- [x] Pruebas de integración contra PostgreSQL local
- [x] Entidades JPA del resto del dominio (meses, gastos, deudas, ahorro, transporte)
- [x] Endpoints CRUD del presupuesto mensual
- [x] Base de datos en Neon aprovisionada y migrada

## Fase 2 — Backend: motor de cálculo

- [x] Calculadora de festivos colombianos (Ley Emiliani), verificada de 2015 a 2050
- [x] Motor de transporte: clasificación de días, pasajes y escenarios
- [x] Resumen mensual: disponible hoy, saldo proyectado, patrimonio neto
- [x] Creación de un mes a partir de las plantillas de gastos fijos
- [x] Endpoints REST y documentación OpenAPI
- [x] 139 pruebas cubriendo los motores y la API completa

**El backend está terminado.** Ver [API.md](API.md).

## Fase 3 — Cliente: base

- [x] Navegación, tema visual y diseño adaptable a móvil/escritorio
- [x] Pantallas de autenticación y almacenamiento seguro de tokens
- [x] Cliente HTTP con renovación automática de token
- [x] Pantalla del mes: sueldo, gastos, marcar como pagado y abonos parciales
- [x] Formato de moneda y fechas en español de Colombia
- [ ] Edición del sueldo y de los gastos desde la pantalla
- [ ] Duplicación del motor de cálculo en Dart, con los mismos casos de prueba
- [ ] Modo sin conexión con caché del mes en curso

## Fase 4 — Cliente: módulos

- [ ] Calendario interactivo de transporte
- [ ] Gestión de deudas externas y abonos
- [ ] Metas de ahorro y distribución del excedente
- [ ] Plantillas de gastos fijos editables
- [ ] Cierre de mes y creación del siguiente

## Fase 5 — Gráficas

- [ ] Distribución del gasto por categoría
- [ ] Evolución de ingresos, gastos y saldo mes a mes
- [ ] Avance de deudas y proyección de liquidación
- [ ] Progreso de las metas de ahorro
- [ ] Presupuestado vs. real en transporte

## Fase 6 — Infraestructura y despliegue

- [x] Terraform: Lambda, Function URL, S3, CloudFront, SSM
- [x] Alerta de presupuesto a $1 y retención de logs a 7 días
- [x] Alarmas de errores y de duración excesiva
- [x] Rol OIDC para despliegues desde GitHub Actions
- [x] Flujos de integración continua para backend y web
- [x] Publicación de versión de Lambda con SnapStart en cada despliegue
- [x] Registros DNS en Hostinger y validación de certificados
- [x] **En producción**: [gastos.axchisan.com](https://gastos.axchisan.com) y
      [api.axchisan.com](https://api.axchisan.com)
- [ ] Volcado semanal de la base de datos a S3

Ver [DESPLIEGUE.md](DESPLIEGUE.md).

## Fase 7 — Pulido

- [ ] Modo sin conexión con sincronización
- [ ] Compilación y firma del APK de Android
- [ ] Compilación de la aplicación de macOS (requiere Xcode completo)
- [ ] Recordatorios de vencimiento de pagos
- [ ] Exportación a CSV/PDF

## Dependencias del entorno

| Herramienta | Estado |
|---|---|
| Java 21 | ✅ instalado (21.0.12) |
| Flutter | ✅ instalado (3.44.8, Dart 3.12.2) |
| AWS CLI | ✅ configurado (cuenta 612216903994) |
| GitHub CLI | ✅ autenticado (axchisan) |
| Terraform | ⬜ pendiente |
| Android SDK | ⬜ pendiente (para compilar el APK) |
| Xcode completo | ⬜ pendiente (solo para la versión de macOS) |
