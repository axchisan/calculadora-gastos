package com.axchisan.calculadora_gastos

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Guarda las notificaciones de pago que publica el teléfono.
 *
 * Es la única forma de enterarse de lo que se paga acercando el móvil: Google Wallet no expone
 * ninguna API para consultarlo, y Android no deja que una aplicación observe lo que hace el
 * servicio de pago. Lo que sí se puede leer es la notificación que aparece en pantalla.
 *
 * Este servicio hace deliberadamente lo mínimo: filtra por aplicación, guarda el texto tal cual
 * y nada más. Interpretar el importe y el comercio se hace en Dart, donde puede probarse contra
 * textos reales sin arrancar un teléfono.
 */
class EscuchaDeNotificaciones : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!esDeInteres(sbn.packageName)) return

        val extras = sbn.notification.extras
        val titulo = extras.getCharSequence("android.title")?.toString().orEmpty()
        val texto = extras.getCharSequence("android.text")?.toString().orEmpty()

        // Sin importe no hay nada que registrar. La comprobación es a propósito grosera —basta
        // con que haya un dígito— porque decidir si es un pago le toca a Dart.
        if (titulo.isBlank() && texto.isBlank()) return
        if (!texto.any { it.isDigit() } && !titulo.any { it.isDigit() }) return

        guardar(
            JSONObject().apply {
                // La clave de Android distingue una notificación de otra; el instante evita que
                // dos avisos idénticos de días distintos se confundan.
                put("id", "${sbn.key}#${sbn.postTime}")
                put("paquete", sbn.packageName)
                put("titulo", titulo)
                put("texto", texto)
                put("instante", sbn.postTime)
            }
        )
    }

    private fun esDeInteres(paquete: String): Boolean =
        PAQUETES_VIGILADOS.any { paquete.contains(it) }

    /**
     * Añade la captura a la lista pendiente.
     *
     * Se guarda en disco y no en memoria porque el servicio y la aplicación son procesos
     * distintos: la notificación puede llegar con la aplicación cerrada, que es lo habitual.
     */
    private fun guardar(captura: JSONObject) {
        val preferencias = getSharedPreferences(ALMACEN, MODE_PRIVATE)
        val actuales = JSONArray(preferencias.getString(CLAVE, "[]"))

        // Android reemite la misma notificación al actualizarla. Sin esta comprobación, una
        // compra podría entrar varias veces.
        val id = captura.getString("id")
        for (i in 0 until actuales.length()) {
            if (actuales.getJSONObject(i).optString("id") == id) return
        }

        actuales.put(captura)

        // Se conservan solo las últimas: si la aplicación pasa semanas sin abrirse, no tiene
        // sentido acumular cientos de capturas que ya no se van a revisar.
        val recortadas = if (actuales.length() <= MAXIMO) {
            actuales
        } else {
            JSONArray().also { destino ->
                for (i in actuales.length() - MAXIMO until actuales.length()) {
                    destino.put(actuales.getJSONObject(i))
                }
            }
        }

        preferencias.edit().putString(CLAVE, recortadas.toString()).apply()
    }

    companion object {
        const val ALMACEN = "capturas_de_pago"
        const val CLAVE = "pendientes"

        private const val MAXIMO = 200

        /**
         * Aplicaciones cuyas notificaciones se miran.
         *
         * Google Wallet cubre todo lo que se paga con el teléfono. La del banco llega además
         * cuando se usa la tarjeta física, y es la única que publica los cuatro últimos dígitos.
         */
        val PAQUETES_VIGILADOS = listOf(
            "walletnfcrel",
            "nu.production",
            "bancolombia",
        )
    }
}
