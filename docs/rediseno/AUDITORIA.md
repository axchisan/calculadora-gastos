# Auditoría de diseño y uso — v1.10.0

Revisión de la app pantalla por pantalla, en el emulador Android con los datos reales del
usuario (22 nov 2026). Este documento no incluye cifras personales, porque el repositorio es
público. Las capturas están fuera del repositorio.

Cada hallazgo lleva una gravedad:

- **Crítico**: hace perder datos o muestra una cifra equivocada.
- **Alto**: obliga a calcular o a interpretar para entender algo básico.
- **Medio**: estorba, ocupa espacio o confunde.
- **Bajo**: detalle de acabado.

---

## 1. Problemas generales

| # | Gravedad | Hallazgo |
|---|---|---|
| G1 | **Crítico** | **Deslizar un ingreso lo borra al instante, sin confirmación y sin deshacer** (`ingresos_extra.dart`, `Dismissible.confirmDismiss`). En una lista larga basta un mal gesto al hacer scroll. Así se perdieron dos ingresos reales de noviembre, que hubo que reconstruir a mano con los extractos. Eliminar un gasto o una deuda tampoco se puede deshacer. |
| G2 | **Crítico** | **«Deuda» y «Patrimonio» del inicio, y «Debes en total» de Deudas, solo suman las deudas informales.** Dejan fuera los créditos con cuadro de cuotas (aunque `CreditoRepository.pendienteTotal` ya existe y no se usa en el resumen) y la tarjeta de crédito. El total que se ve es una fracción pequeña de lo que se debe de verdad. |
| G3 | Alto | **Tema**: sigue al del teléfono y no hay forma de elegirlo. Los dos temas salen de un `ColorScheme.fromSeed` verde azulado sin ajustar: el fondo tintado de verde, las tarjetas con borde y el botón flotante menta son el aspecto de plantilla de Material 3 que da la sensación de «diseño hecho por IA». |
| G4 | Alto | **Exceso de cifras.** El primer pantallazo del inicio muestra 15 importes y 4 colores semánticos a la vez. Hay centavos en todas partes (`,08`, `,78`, `,20`) aunque para decidir no aportan nada. |
| G5 | Alto | **El color no jerarquiza.** El rojo, el naranja y el verde se usan para cosas que no son alertas («Gastado en el día a día» en verde, «Gastos por pagar» en naranja). Cuando todo resalta, nada resalta. |
| G6 | Medio | **Seis pestañas** (Material recomienda de 3 a 5). Dos no se usan hoy (Transporte, Ahorro) y ocupan sitio, mientras dos de las pantallas más útiles (Mis cuentas, Mi sueldo) están escondidas en el menú ⋮. La etiqueta «Transporte» se parte en dos líneas. |
| G7 | Medio | **Tarjeta dentro de tarjeta.** Todo va en recuadros con borde, incluidas las listas, y los recuadros se apilan. El espacio no separa ni agrupa: lo hacen las líneas. |
| G8 | Medio | El **botón flotante tapa contenido** (importes de ingresos y gastos al final de cada lista). |
| G9 | Medio | **Textos truncados**: «116% del sueld…», «Compromet…», «Gastos en efectivo sin detallar…». |
| G10 | Medio | **Conceptos que hacen de notas.** Como no hay campo de notas en ingresos, los conceptos llevan fórmulas enteras, con sumas y restas de varias transferencias. Se leen como un extracto contable. |

---

## 2. Mes (inicio)

Captura base: el primer pantallazo, que es lo que el usuario mira a diario.

| # | Gravedad | Hallazgo |
|---|---|---|
| M1 | Alto | **Dos modos («Real» y «Estimación») con cifras contradictorias.** En Real: «Disponible hoy» en verde y, en la misma tarjeta, «Al cerrar» en rojo negativo. En Estimación: «Te quedaría…» en rojo y «116% del sueldo». Nada explica por qué las dos cifras son distintas ni cuál mirar. |
| M2 | Alto | **La tarjeta principal tiene cuatro bloques**: barra Pagado/Falta, cuatro subtotales, una fila Ingreso/Gastos/Al cerrar y otra Ahorrado/Deuda/Patrimonio. Para responder «¿cómo voy?» hay que leer 11 números. |
| M3 | **Crítico** | «Deuda» y «Patrimonio» salen mal: ver G2. |
| M4 | Medio | **«Dinero real hoy» repite casi la misma cifra** que «Disponible hoy», justo debajo. Cuadrar es valioso, pero bastaría con un indicador («Cuadra ✓» o «Faltan X por registrar»). |
| M5 | Alto | **«Ingresos extra» es una lista de 14 filas siempre abierta.** Mezcla el saldo inicial del mes, préstamos (dinero que entra pero se debe), intereses de centavos, apoyos familiares y trabajos sueltos, todos con el mismo peso visual. Para llegar a los gastos hay que hacer scroll durante tres pantallas. |
| M6 | Medio | **«Por pagar» y «Pagado»**: los pagados aparecen tachados, que se lee como «cancelado». No hay fecha de vencimiento a la vista. Sale «Transporte $0» con un ícono de chispa que no se explica. |
| M7 | Alto | **No hay «próximos pagos».** Los vencimientos de las próximas semanas (tarjeta, préstamos, cuotas de crédito, servicios) están repartidos entre Mes, Deudas y el mes siguiente. Hoy no se puede ver de un vistazo que dos pagos grandes caen el mismo día. |
| M8 | Medio | El título-selector de mes más las dos flechas más el ⋮ llenan la barra superior de controles para algo que se cambia pocas veces. |
| M9 | Bajo | Menú ⋮ con 8 opciones de naturalezas distintas: navegación (cuentas, sueldo), acciones (traer gastos fijos, cerrar el mes) y sistema (recargar, mi cuenta). |

## 3. Diario

| # | Gravedad | Hallazgo |
|---|---|---|
| D1 | Bajo | Es la pantalla mejor resuelta: agrupa por día, pone el total del día y las filas son legibles. Es un buen punto de partida para el nuevo lenguaje visual. |
| D2 | Medio | Las métricas del resumen («Media por día», «Día más caro», «Días con gasto») no ayudan a decidir. Faltan «cuánto llevo en comida», «cuánto en la mascota», etc. |
| D3 | Medio | El ícono de cada fila indica el **medio de pago** (banco o efectivo), no la categoría. Escanear por tipo de gasto no es posible. |
| D4 | Medio | No hay búsqueda ni filtro por categoría, medio o cuenta. Tampoco hay selector de mes: depende del mes elegido en el inicio. |
| D5 | Medio | Las suscripciones mensuales (YouTube, Crunchyroll, Google) aparecen como compras del día, mezcladas con lo variable. |
| D6 | Medio | «Tarjetas» y la detección automática viven detrás de un ícono sin texto. El panel de detección enseña cuatro ✕ rojas y seis botones: alarmante y técnico para una función secundaria. |
| D7 | Bajo | **Formulario «Nueva compra»**: el teclado numérico propio y las sugerencias están muy bien. Pero las sugerencias ocupan media pantalla en columna y las categorías se cortan bajo el teclado. |

## 4. Transporte

| # | Gravedad | Hallazgo |
|---|---|---|
| T1 | Alto | **Muestra un costo mensual y un calendario de oficina/karate que ya no aplican**: el usuario no se desplaza a diario. Ocupa una pestaña entera y su gasto fijo sigue apareciendo en el mes. |
| T2 | Medio | Debe pasar a ser un **módulo opcional** que se activa en Ajustes. |

## 5. Deudas

| # | Gravedad | Hallazgo |
|---|---|---|
| E1 | **Crítico** | «Debes en total» solo cuenta las deudas informales (ver G2). Los créditos aparecen debajo con su saldo, pero no suman. |
| E2 | Alto | **La tarjeta de crédito no existe como deuda.** Solo aparece como gasto del mes en que se paga. Su saldo total y sus cuotas no se ven en ningún sitio. |
| E3 | Alto | **No hay vista en el tiempo.** Falta lo que el usuario pidió: «¿cuánto debo en total y cómo baja mes a mes?», con la fecha en que queda libre de cada deuda y de todas. |
| E4 | Medio | «Has pagado X de Y» mezcla lo abonado a deudas ya saldadas con las vivas. Las saldadas ocupan media pantalla. |
| E5 | Medio | El título es «Noviembre 2026», pero las deudas no dependen del mes. |
| E6 | Medio | **Detalle de crédito**: tiene buen contenido (lo que cuesta, cuánto devuelves en total, simulador de abono), pero el cuadro de pagos son 18 tarjetas de tres líneas cada una. Hace falta una tabla compacta o una gráfica. |
| E7 | Bajo | En el detalle de una deuda, «Eliminar esta deuda» está a la misma altura visual que «Abonar» y «Editar». |

## 6. Ahorro

| # | Gravedad | Hallazgo |
|---|---|---|
| A1 | Medio | Una pestaña entera para un estado vacío. El usuario planea usarlo, pero hoy no tiene metas. |
| A2 | Medio | Propuesta: «Metas» como módulo opcional, con una tarjeta pequeña en el inicio cuando haya alguna, y la pestaña solo si se activa. |

## 7. Gráficas

| # | Gravedad | Hallazgo |
|---|---|---|
| R1 | Alto | **La dona de «En qué se va el mes» tiene 10 categorías y 6 de ellas comparten el mismo gris.** No se distinguen sin leer la leyenda. |
| R2 | Alto | **«Deudas» se lleva el 54 % de la dona** y aplasta el resto. Los abonos a deudas no son consumo: deben ir aparte para que la gráfica responda «¿en qué gasto?». |
| R3 | Alto | **La curva «Mes a mes» está suavizada y baja por debajo de $0** (julio), un artefacto de la interpolación que muestra un valor imposible. Además mezcla meses reales con meses futuros estimados sin distinguirlos. |
| R4 | Medio | «Avance de las deudas» solo muestra las deudas informales (ver G2). |
| R5 | Medio | El selector Real/Estimación se repite aquí con el mismo problema que en el inicio. |

## 8. Pantallas secundarias

| # | Gravedad | Hallazgo |
|---|---|---|
| S1 | Bajo | **Mis cuentas**: limpia y útil. Merece estar a un toque desde el inicio, no en el menú. |
| S2 | Medio | **Mi sueldo**: cuatro tarjetas casi iguales (una por mes futuro) con «Cómo se calcula» y «Ya me llegó» repetidos en cada una. Bastaría con el próximo pago destacado y el resto en una lista. |
| S3 | Medio | **Mi sueldo**: «Poner estos pagos como sueldo de cada mes» es un paso manual que se olvida. El sueldo base del mes se queda con una TRM vieja. Debería actualizarse solo mientras no haya llegado el pago. |
| S4 | Medio | **Gastos fijos**: los inactivos (tachados) se mezclan con los activos y ocupan la mitad de la lista. |
| S5 | Bajo | **Mi cuenta**: no hay ajustes de la app (tema, módulos visibles, formato de importes). |

---

## 9. Lo que falta en la app

Por cómo se ha ido registrando la información en estos meses:

1. **Selector de tema** (claro por defecto, oscuro, según el sistema).
2. **Deuda total consolidada**: créditos, tarjetas y deudas informales, con una **proyección mes
   a mes** hasta llegar a cero.
3. **Tarjeta de crédito como deuda**, con su saldo y sus cuotas, además del pago del mes.
4. **Próximos pagos**: una línea de tiempo de los próximos 30 días con todo lo que vence.
5. **Deshacer** en cualquier borrado, y confirmación en los borrados masivos o irreversibles.
6. **Notas** separadas del concepto en ingresos y gastos.
7. **Tipos de ingreso**: sueldo, saldo inicial, préstamo recibido, apoyo familiar, trabajo
   extra. Así los préstamos no se cuentan como ingreso «ganado».
8. **Cuentas por cobrar**: lo que otros le deben al usuario. Hoy se anota en las notas del mes.
9. **Transferencias entre cuentas propias**, para que el cuadre con los bancos no dependa de
   omitirlas a mano.
10. **Recordatorios** de vencimientos (notificación local).
11. **Módulos opcionales** (Transporte, Ahorro) que se activan o desactivan.

## 10. Lo que funciona y hay que conservar

- El cuadre «Dinero real hoy» frente a la app: es la función más valiosa para confiar en los
  números.
- El teclado numérico propio y las sugerencias del formulario de compra.
- La agrupación por día del Diario.
- El detalle de crédito: cuánto cuesta y cuánto devuelves en total, más el simulador de abono.
- Mi sueldo: la TRM oficial automática y el «Ya me llegó».
- El trabajo sin conexión (caché local del mes).
