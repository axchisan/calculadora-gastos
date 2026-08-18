# Capturar automáticamente los pagos del teléfono

Casi todas las compras del día a día se pagan acercando el teléfono al datáfono, con la tarjeta
guardada en Google Wallet. Apuntarlas después a mano es justo el paso que se olvida. La pregunta
es si la aplicación puede enterarse sola.

## Lo que no se puede hacer

**Google Wallet no tiene ninguna API para leer transacciones.** Conviene decirlo claro porque
hay artículos que dan a entender lo contrario.

Lo que sí existe se llama Google Wallet API, pero es otra cosa: sirve para **emitir** pases
—tarjetas de fidelización, entradas, tarjetas de embarque— y para meterlos en la billetera del
usuario. No hay ningún método para preguntar «¿qué pagó esta persona?».

El propio historial de la aplicación de Google Wallet muestra solo los últimos movimientos
hechos desde ese teléfono, y lo hace en su interfaz; no lo publica a nadie.

Tampoco sirve el NFC del teléfono. Android permite emular una tarjeta (*Host Card Emulation*),
pero solo puede haber un servicio de pago activo, que es Google Wallet, y una aplicación no
puede espiar lo que hace otra. Es una frontera de seguridad del sistema, no una limitación de
la API.

## Lo que sí se puede hacer

Queda una vía, y funciona: **leer las notificaciones que el propio teléfono ya muestra.**

Cuando se paga con la billetera, Google Wallet publica una notificación con el importe y el
comercio. El banco suele publicar otra. Android permite que una aplicación las lea mediante un
`NotificationListenerService`, con un permiso que el usuario concede a mano en los ajustes del
sistema.

Es el mecanismo que usan las aplicaciones de gastos que anuncian «registro automático». No hay
magia detrás: leen la notificación.

### Lo que implica

| | |
|---|---|
| **Solo en Android** | La web y macOS seguirían con registro manual. iOS no permite nada parecido. |
| **Permiso especial** | Se concede una vez en Ajustes → Notificaciones → Acceso a notificaciones. Es un permiso amplio: da acceso a **todas** las notificaciones del teléfono, no solo a las de pago. |
| **Depende del texto** | Hay que reconocer el importe y el comercio dentro de un texto que escribe Google, y que cambia con las versiones y con el idioma. |
| **Fuera de Play Store** | Google restringe este permiso en las apps publicadas, y Android lo bloquea en las instaladas desde un APK suelto. Tiene arreglo, pero hay que saberlo: ver más abajo. |

### Lo que llega de verdad

Estos son los textos reales de una compra del 17 de agosto de 2026. Llegan **dos**
notificaciones por la misma compra:

**Google Wallet**, que llega en todo pago con el teléfono, sea la tarjeta que sea:

```
título:  SURTIMAYORISTA CLARET
texto:   COP54,670.00 with crédito física
```

**El banco**, que llega también al usar la tarjeta física:

```
título:  Compra aprobada por $54.670,00
texto:   Tu compra en SURTIMAYORISTA CLARET por $54.670,00 con tu tarjeta
         terminada en 2355 ha sido APROBADA.
```

Hay dos detalles que muerden si no se tratan:

**Los importes vienen en formatos opuestos.** Google Wallet escribe `54,670.00`, a la americana,
porque el sistema del teléfono está en inglés; el banco escribe `54.670,00`, a la colombiana. El
punto y la coma significan lo contrario en cada uno, así que dar por buena una convención
convertiría 54.670 pesos en 54,67.

La regla que los distingue sin ambigüedad: **el último separador es el decimal solo si le siguen
exactamente dos dígitos.** Con tres es separador de miles.

**Llegan dos avisos por compra.** Se juntan por importe dentro de una ventana de cinco minutos,
conservando lo que aporta cada uno: la billetera trae el comercio limpio en el título y el apodo
de la tarjeta; el banco trae los cuatro dígitos.

### El punto delicado: débito o crédito

Para la aplicación no es lo mismo pagar con débito que con crédito: lo primero sale del dinero
de este mes y lo segundo se va al corte de la tarjeta, uno o dos meses después. Y ninguna de
las dos notificaciones dice cuál es.

Lo que sí dicen es **cómo se llama la tarjeta**: la billetera por su apodo («crédito física») y
el banco por sus cuatro dígitos («terminada en 2355»). La tabla `card_aliases` traduce eso a la
tarjeta de la aplicación, y de ahí sale si es débito o crédito.

Los cuatro dígitos mandan sobre el apodo: no dependen de cómo se haya escrito nada. Los apodos
se comparan en minúsculas y sin tildes, porque se escriben a mano y no siempre igual — en la
misma billetera conviven «crédito física», con tilde, y «credito digital», sin ella.

Una tarjeta admite varios apodos, porque Nu entrega una virtual y una física sobre la misma
línea de crédito: números distintos, apodos distintos y un solo corte.

## Diseño propuesto

Lo importante es que **una notificación mal interpretada no ensucie las cuentas**. Un importe
leído de más o un comercio que no era, metidos directamente en el presupuesto, harían perder la
confianza en las cifras, que es lo único que esta aplicación tiene que ofrecer.

Por eso las capturas no se convierten en compras solas: caen en una bandeja.

```
notificación de pago
        ↓
  servicio de Android           lee el texto, extrae importe y tarjeta
        ↓
  bandeja de capturas           «$12.500 · OXXO · Nu ••4821»
        ↓
  un toque del usuario          confirma la categoría y guarda
        ↓
  compra registrada             con origen = NOTIFICACION
```

Un toque en vez de escribir importe, comercio, medio de pago y fecha. Sigue siendo casi
automático, pero el usuario ve lo que entra.

La bandeja guarda además el texto original de cada notificación. Es lo que permite ajustar el
reconocimiento contra lo que de verdad llega al teléfono, en lugar de adivinarlo.

### Piezas

| Dónde | Qué |
|---|---|
| `EscuchaDeNotificaciones.kt` | `NotificationListenerService` que filtra por aplicación y guarda el texto tal cual |
| `MainActivity.kt` | Canal de plataforma: permiso, lectura y descarte de capturas |
| `captura_pago.dart` | El reconocimiento: importes, comercio, tarjeta y deduplicado |
| `bandeja_capturas.dart` | La bandeja, dentro de Gastos diarios |
| `card_aliases` | La traducción entre lo que dice la notificación y la tarjeta de la aplicación |

**El reconocimiento vive en Dart y no en Kotlin a propósito.** Así se puede probar contra los
textos reales sin arrancar un teléfono, que es lo que permite tener cubierto el caso de los dos
formatos de importe y el de las tildes que van y vienen. La parte nativa se limita a capturar.

### Alternativa: los SMS del banco

En Colombia los bancos mandan un SMS por cada compra, con importe y comercio. Leerlos exige el
permiso `READ_SMS`, todavía más amplio que el de notificaciones.

Tiene una ventaja real: el SMS llega igual aunque se pague con la tarjeta física, no solo con el
teléfono. Y una desventaja, que el formato varía de un banco a otro.

Puede convivir con lo anterior: las dos fuentes alimentan la misma bandeja, con un filtro para
no registrar dos veces la misma compra.

## El obstáculo de los ajustes restringidos

Instalar la aplicación abriendo el APK desde el gestor de archivos deja dos problemas, y los
dos vienen de lo mismo: **Android anota quién instaló cada aplicación, y un APK abierto a mano
no tiene instalador anotado.**

- Play Protect avisa de que la aplicación es desconocida y hay que insistir para continuar.
- Android 13 marca el acceso a notificaciones como **ajuste restringido**: el interruptor sale
  apagado, no se deja tocar y el sistema muestra «Controlled by restricted setting» junto a un
  aviso de que el permiso puede poner en riesgo la información financiera. Lo que **no** dice es
  qué hacer al respecto.

### La solución limpia: instalar por cable

```bash
scripts/instalar-en-el-telefono.sh
```

Por dentro hace `adb install -r -i com.android.vending`. Ese `-i` anota Play Store como
instalador, con lo que Android deja de considerarla una instalación lateral y **ninguna de las
dos restricciones se aplica**. Ni aviso de Play Protect, ni ajuste restringido.

Requiere activar la depuración por USB una vez: Ajustes → Acerca del teléfono → tocar siete
veces «Número de compilación», y allí encender «Depuración por USB».

### Si se instaló desde el archivo

Se puede desbloquear a mano, aunque el camino no es evidente:

1. Ajustes → Aplicaciones → **Mis gastos**
2. Menú de **tres puntos** arriba a la derecha → **«Permitir ajustes restringidos»**
3. Volver al acceso a notificaciones y encender el interruptor, que ya se dejará tocar

Si esa opción del menú no aparece, hay que entrar antes una vez en el acceso a notificaciones e
intentar encender el interruptor. Al rechazarlo, Android habilita la opción.

La aplicación detecta si se instaló de lado —consultando el instalador anotado— y enseña estos
pasos en lugar de mandar al usuario a un interruptor muerto sin explicación.

## Cómo se activa

1. En **Gastos diarios → Tarjetas**, tocar «Detectar pagos automáticamente». Se abre la guía con
   los pasos que hagan falta según cómo se instalara la aplicación.
2. En cada tarjeta, el icono de la campana abre sus apodos. Hay que añadir el nombre que tiene
   dentro de Google Wallet y, si se sabe, sus cuatro últimos dígitos.

A partir de ahí, los pagos aparecen en la bandeja de Gastos diarios con el importe, el comercio
y la tarjeta ya puestos. Solo queda elegir la categoría.

Si una notificación menciona una tarjeta que la aplicación no conoce, lo dice en vez de
adivinar: sin identificarla no se sabe si el pago fue con débito o con crédito.

## Lo que queda fuera

- **Solo Android.** En la web y en macOS el registro sigue siendo a mano.
- **Solo lo que se pague con el teléfono o con las tarjetas cuyo banco notifique.** Una compra en
  efectivo no genera ninguna notificación.
- **Los SMS del banco**, que cubrirían los pagos con tarjeta física de bancos que no tienen app
  con notificaciones. Exigen `READ_SMS`, un permiso todavía más amplio.
