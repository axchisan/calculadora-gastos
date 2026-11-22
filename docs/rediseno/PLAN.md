# Plan de rediseño — v2.0

Parte de la [auditoría](AUDITORIA.md). Objetivo: una app de uso personal que responda de un
vistazo, sin cálculos mentales, a tres preguntas:

1. **¿Cuánto tengo y cuánto puedo gastar?**
2. **¿Qué tengo que pagar pronto?**
3. **¿Cuánto debo en total y cuándo termino de pagarlo?**

## 1. Principios

- **Un número protagonista por pantalla.** El resto, en segundo plano o a un toque.
- **El color significa algo.** Neutro por defecto. Rojo solo para lo que está mal (saldo
  negativo, pago vencido); verde solo para lo que se completó; un único color de acento para
  las acciones.
- **El espacio agrupa, no los bordes.** Sin tarjetas dentro de tarjetas; secciones separadas
  por aire y títulos.
- **Pesos sin centavos** en las listas y los resúmenes. Los centavos solo en el detalle y al
  editar.
- **Lenguaje de persona, no de contador**: «Te quedan», «Pagas el 4 dic», «Terminas de pagar
  en junio».
- **Nada se borra sin red**: cualquier borrado se puede deshacer durante unos segundos.

## 2. Lenguaje visual (propuesta inicial, se cierra con el prototipo)

- **Tema claro por defecto**, con un oscuro de verdad y la opción «según el sistema» en
  Ajustes.
- Fondo blanco roto o gris muy claro, superficies blancas sin borde y sombra mínima o
  ninguna. Texto casi negro; un gris para lo secundario.
- Un solo acento, sobrio (tinta oscura o un color propio, no el verde azulado de Material por
  defecto). Positivo, negativo y aviso desaturados.
- Tipografía con **cifras tabulares**, para que los importes se alineen; pesos 400/500/600 y
  pocos tamaños (por ejemplo 12, 14, 16, 20, 32 y 40).
- Íconos de línea finos, uno por categoría (no por medio de pago).
- Movimiento discreto: transiciones cortas y nada que rebote.

## 3. Nueva estructura

Cuatro pestañas más el perfil y los ajustes:

| Pestaña | Contenido |
|---|---|
| **Inicio** | Disponible hoy (protagonista) con el estado del cuadre con los bancos · Próximos pagos (14–30 días) · Resumen del mes en dos cifras: entró y salió · Accesos a Mis cuentas y Mi sueldo · Metas, si hay alguna |
| **Movimientos** | Una sola línea de tiempo con ingresos, gastos fijos y compras del día a día, agrupada por día · Filtros (tipo, categoría, cuenta) y búsqueda · Gastos fijos del mes como lista corta de «pendientes» arriba · Botón único «+» para apuntar ingreso, gasto o compra |
| **Deudas** | **Total que debes** (créditos + tarjetas + informales) · Gráfica de cómo baja mes a mes y fecha en que terminas · Lista ordenada por el próximo vencimiento · Saldadas plegadas |
| **Análisis** | En qué se va el dinero (barras horizontales por categoría, sin los abonos a deudas) · Mes a mes (barras, reales frente a estimados) · Evolución de la deuda total |

**Ajustes** (desde el avatar): tema, módulos visibles (Transporte, Ahorro), gastos fijos,
tarjetas y detección automática, mi cuenta.

## 4. Fases

Cada fase se cierra igual: pruebas (`flutter analyze`, `dart format`, `flutter test` y las del
backend si se tocan), revisión en el emulador con los datos reales, aprobación del usuario,
commit y despliegue.

| Fase | Qué | Backend | Estado |
|---|---|---|---|
| **0. Red de seguridad** | Borrado diferido con «Deshacer» en ingresos, gastos, compras y deudas (`ui/comun/deshacer.dart`). | — | Hecha, sin publicar |
| **1. Propuesta visual** | Prototipo navegable de las cuatro pestañas con datos reales, en claro y oscuro. | — | Aprobada el 22 nov |
| **2. Sistema de diseño** | Tokens (color, tipografía Manrope con cifras tabulares, espaciado), tema claro por defecto con selector Claro / Oscuro / Sistema, componentes base: importe, sección, fila de movimiento, chip, estado vacío, hoja inferior, aviso. | — | Hecha, sin publicar |
| **3. Datos locales y sin conexión** | Ver el apartado 5. Va antes de las pantallas para que las nuevas se construyan ya sobre datos locales. 3a: lectura local de todo, precarga y aviso sin conexión. 3b: cola de pendientes. 3c: ETag y `/api/inicio`. | Revalidación barata, endpoint de inicio, identificadores del cliente | 3a y 3b hechas (v1.12.0) |
| **4. Navegación e Inicio** | Cuatro pestañas, Ajustes y el nuevo Inicio con «Próximos pagos». | Endpoint de próximos vencimientos | Pendiente |
| **5. Movimientos** | Línea de tiempo unificada, filtros, «+» único, notas en ingresos, tipos de ingreso, categoría Mascota. Apuntar sin conexión. | Notas y tipo de ingreso (migración) | Pendiente |
| **6. Deudas** | Total consolidado, proyección mes a mes, tarjeta de crédito como deuda, cuadro de cuotas compacto, «Te deben». | Arreglar la deuda total del resumen; proyección; saldo de tarjeta; cuentas por cobrar | Pendiente |
| **7. Análisis** | Gráficas nuevas sin artefactos y frases con lo importante del mes. | Serie de deuda total | Pendiente |
| **8. Secundarias** | Mis cuentas, Mi sueldo (próximo pago destacado, sueldo base automático), Gastos fijos, Transporte y Ahorro como módulos opcionales. | Sueldo base automático | Pendiente |
| **9. Pulido y publicación** | Accesibilidad (contraste, tamaños de toque, lector de pantalla), escritorio y web, versión 2.0.0 en teléfono, Mac y web. | — | Pendiente |

El arreglo de la deuda total (G2) puede adelantarse si se quiere ver el dato correcto antes de
la fase 6.

## 5. Datos locales y sin conexión (fase 3)

**Situación actual.** Solo el mes en curso (resumen, gastos e ingresos) se guarda en el
teléfono, en `SharedPreferences`. Diario, Deudas, créditos, Mis cuentas, Mi sueldo y Gráficas
piden todo al servidor cada vez: sin conexión no muestran nada, y con conexión cada pestaña
espera el arranque en frío de Lambda. Sin red, la app tarda hasta 15 s en rendirse
(`Configuracion.esperaConexion`).

**Objetivo.** Abrir la app y cualquier pestaña al instante, con o sin conexión; poder apuntar
lo del día sin red; que nunca haya duda de si lo que se ve está al día.

### 5.1 Lectura: mostrar lo guardado al instante y actualizar detrás

- **Una sola capa para todo**, en lugar de caché a mano en cada repositorio: un interceptor de
  Dio guarda cada respuesta GET correcta, identificada por usuario y ruta, en un almacén local.
  Los controladores siguen el patrón *stale-while-revalidate*: pintan lo guardado en el primer
  fotograma y piden la versión nueva por detrás. Si llega distinta, la pantalla se actualiza
  sin parpadear.
- **Almacén**: se mantiene `SharedPreferences` detrás de `CacheLocal`. Todas las lecturas de un
  usuario ocupan del orden de cientos de KB, muy por debajo de lo que justifica otra base
  local, y así no hay migración ni dependencia nueva. Si el volumen crece (por ejemplo, años de
  historial), `CacheLocal` es el único punto que cambiar, y entonces `hive_ce` es la opción
  (Dart puro, IndexedDB en la web). Cada lectura se guarda por usuario y ruta completa; un
  formato ilegible se descarta en lugar de fallar.
- **Precarga al abrir**: en paralelo se piden el mes actual, las compras, las deudas, los
  créditos, las cuentas y el sueldo, de modo que todas las pestañas están listas antes de
  tocarlas. También al volver a primer plano, si pasaron más de unos minutos.
- **Indicador honesto**: una línea discreta, «Sin conexión · datos de hace 2 h» o «Actualizando…»,
  en lugar de pantallas de error. Un error solo se muestra si no hay nada guardado.

### 5.2 Sin conexión: detectarlo rápido

- Sin dependencia nueva: en modo avión la petición falla al instante, y con red mala las
  lecturas que tienen copia local esperan como mucho 5 s para conectar (antes 15 s). Sin copia
  local se mantiene la espera larga, por el arranque en frío.
- Al perder la red se comprueba `/api/salud` cada 20 s; al volver, se revisa todo lo mostrado.
  También se revisa todo al volver a la app tras más de 2 minutos fuera.

### 5.3 Escritura sin conexión: cola de pendientes

- Las acciones del día a día (**apuntar una compra, un ingreso o un gasto, y marcar un gasto
  como pagado**) se guardan en una cola local cuando no hay red. Se muestran enseguida en las
  listas con una marca de «pendiente de subir» y se envían en orden al volver la conexión.
- **Sin duplicados**: la app genera el identificador (UUID v7) y el backend lo acepta como
  opcional; reintentar un envío que ya llegó no crea otro registro.
- Editar y borrar siguen exigiendo conexión. Con un solo usuario los conflictos son raros, pero
  editar sin red algo que cambió en otro dispositivo no compensa la complejidad.
- Si un envío falla por validación (no por red), el elemento queda marcado en rojo para
  corregirlo o descartarlo; nunca se pierde en silencio.

### 5.4 Backend

- `ETag` en las lecturas principales: la revalidación responde `304 Not Modified` sin cuerpo
  cuando nada cambió. Es más rápida y gasta menos datos.
- `GET /api/inicio`: un solo endpoint con todo lo que necesita la pantalla de Inicio (resumen,
  próximos pagos, cuentas, próximo sueldo), para no encadenar varias peticiones en frío.
- Identificadores opcionales enviados por el cliente al crear (ver 5.3).

### 5.5 Pruebas

- Unitarias del almacén (guardar, leer, caducar, versión) y de la cola (orden, reintento, sin
  duplicados).
- De widgets: cada pantalla pinta lo guardado sin red y muestra el indicador.
- De integración en el backend para `ETag`, `/api/inicio` y la creación con identificador.
- Manual en el emulador: modo avión, abrir cada pestaña, apuntar una compra, volver a conectar
  y comprobar que se subió una sola vez.

## 6. Después del rediseño: registro automático de movimientos

Pendiente, para cuando termine el rediseño. La captura actual por notificaciones y SMS
(`docs/CAPTURA-DE-PAGOS.md`) no ha resultado fiable en el uso real. Se hará primero una
investigación a fondo: APIs de los bancos, open finance en Colombia, agregadores y servicios de
terceros, y cualquier integración que funcione de verdad (como mínimo Bancolombia; mejor si
cubre también billeteras y otros bancos). Se compararán fiabilidad, costo, seguridad y si aplican
a una persona natural, y solo después se elegirá qué implementar.

## 7. Herramienta para la propuesta visual

Opciones para la fase 1:

| Opción | A favor | En contra |
|---|---|---|
| **Prototipo HTML navegable** (página privada en claude.ai) | Rápido de iterar; se abre en el teléfono como si fuera la app; interactivo (pestañas, hojas, modo claro/oscuro); los mismos tokens pasan directo a Flutter | No es un archivo de diseño editable a mano |
| **Figma** (conectado por MCP) | Archivo de diseño editable, comentarios en contexto, sirve de referencia permanente | Más lento de generar y de iterar; menos fiel al comportamiento real (scroll, hojas, teclado) |
| **Directo en Flutter** | Lo que se ve es lo que queda | Iterar el diseño cuesta compilar e instalar cada vez; peor para comparar alternativas |

Recomendación: **prototipo HTML navegable para decidir**, y pasar a Figma solo las pantallas
aprobadas si se quiere un archivo de referencia.
