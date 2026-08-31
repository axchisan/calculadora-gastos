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
- [x] Integración continua

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
- [x] Cuotas de deuda proyectadas dentro del cupo comprometido del mes
- [x] 247 pruebas cubriendo los motores y la API completa

**El backend está terminado.** Ver [API.md](API.md).

## Fase 3 — Cliente: base

- [x] Navegación, tema visual y diseño adaptable a móvil/escritorio
- [x] Pantallas de autenticación y almacenamiento seguro de tokens
- [x] Cliente HTTP con renovación automática de token
- [x] Pantalla del mes: sueldo, gastos, marcar como pagado y abonos parciales
- [x] Formato de moneda y fechas en español de Colombia
- [x] Edición del sueldo y de los gastos desde la pantalla
- [x] Modo sin conexión con caché del mes en curso
- [ ] Duplicación del motor de cálculo en Dart, con los mismos casos de prueba

## Fase 4 — Cliente: módulos

- [x] Calendario interactivo de transporte
- [x] Ajustes de cuenta: cambio de nombre, correo y contraseña
- [x] Gestión de deudas externas y abonos
- [x] Metas de ahorro y distribución del excedente
- [x] Navegación entre secciones adaptada a móvil y escritorio
- [x] Plantillas de gastos fijos editables
- [x] Cierre y reapertura del mes
- [x] Gastos del día a día, separados de los compromisos mensuales
- [x] Tarjetas con ciclo de facturación: lo que se compra a crédito se paga en su mes
- [x] Deudas filtradas por el mes al que corresponden
- [x] Captura automática de los pagos con el teléfono — ver
      [CAPTURA-DE-PAGOS.md](CAPTURA-DE-PAGOS.md)
- [x] Leer también los SMS del banco, para las compras con la tarjeta física
- [x] Servicio en primer plano opcional, para que la detección no dependa de abrir la app
- [x] Créditos con cuadro de amortización y simulación de abonos extraordinarios
- [x] Importes con centavos y compras fechadas en el mes anterior
- [x] Separadores en vivo y lectura de la coma decimal en todos los formularios

## Fase 5 — Gráficas

- [x] Distribución del gasto por categoría
- [x] Evolución de ingresos y gastos mes a mes
- [x] Avance de las deudas
- [ ] Progreso de las metas de ahorro en gráfica
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

## Fase 7 — Publicación

- [x] Compilación del APK de Android
- [x] Compilación de la aplicación de macOS
- [x] Icono propio en las tres plataformas, generado por código
- [x] Nombre, identificadores y versión de cada plataforma
- [x] Tamaño y mínimo de la ventana en macOS
- [x] Icono de Android idéntico al de macOS bajo cualquier máscara de lanzador
- [x] Apartado con la versión instalada, la plataforma y el servidor
- [x] Permiso de internet en el manifiesto de publicación de Android
- [x] Firma de publicación leída de `key.properties` si existe
- [x] APK por arquitectura: 20 MB en vez de 57
- [x] Pantalla de carga en la web
- [ ] Generar la clave propia y guardar copia (necesario para Play Store)
- [ ] Recordatorios de vencimiento de pagos
- [ ] Exportación a CSV/PDF

Ver [APLICACIONES.md](APLICACIONES.md).

## Dependencias del entorno

| Herramienta | Estado |
|---|---|
| Java 21 | ✅ instalado (21.0.12) |
| Flutter | ✅ instalado (3.44.8, Dart 3.12.2) |
| AWS CLI | ✅ configurado (cuenta 612216903994) |
| GitHub CLI | ✅ autenticado (axchisan) |
| Terraform | ✅ instalado (1.15.8) |
| Android SDK | ✅ instalado (36.0.0) |
| Xcode | ✅ instalado (26.6) |
| CocoaPods | ✅ instalado |
| PostgreSQL | ✅ instalado (17.10) |
