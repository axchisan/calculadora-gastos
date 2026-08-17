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
| **Fuera de Play Store** | Google restringe mucho este permiso en las apps publicadas. Para una aplicación personal instalada por APK no hay problema. |

### El punto delicado: débito o crédito

Aquí está la parte que no resuelve la notificación por sí sola. Para la aplicación no es lo
mismo pagar con débito que con crédito: lo primero sale del dinero de este mes y lo segundo se
va al corte de la tarjeta, uno o dos meses después.

La notificación de Google Wallet indica la tarjeta usada, normalmente por los últimos cuatro
dígitos. Eso permite asociarla a una tarjeta ya registrada en la aplicación, y de ahí sale si es
débito o crédito. Pero hay que configurarlo una vez por tarjeta.

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
| Android | `NotificationListenerService` en Kotlin, filtrando por el paquete de Google Wallet y los de los bancos |
| Android | Canal de plataforma para pasar las capturas a Flutter |
| Flutter | Pantalla de ajustes para conceder el permiso y asociar cada tarjeta a las suyas |
| Flutter | Bandeja de capturas pendientes, con confirmación de un toque |
| Backend | Ya está: `purchases.origen = NOTIFICACION` existe desde la primera versión de la tabla |

### Alternativa: los SMS del banco

En Colombia los bancos mandan un SMS por cada compra, con importe y comercio. Leerlos exige el
permiso `READ_SMS`, todavía más amplio que el de notificaciones.

Tiene una ventaja real: el SMS llega igual aunque se pague con la tarjeta física, no solo con el
teléfono. Y una desventaja, que el formato varía de un banco a otro.

Puede convivir con lo anterior: las dos fuentes alimentan la misma bandeja, con un filtro para
no registrar dos veces la misma compra.

## Estado

Pendiente de construir. El backend ya lo admite; falta la parte de Android y la bandeja.

El primer paso no es escribir el reconocimiento a ciegas, sino **capturar unas cuantas
notificaciones reales de pago y ver exactamente qué texto llega**. Con eso, el reconocimiento
sale a la primera en lugar de a base de intentos.
