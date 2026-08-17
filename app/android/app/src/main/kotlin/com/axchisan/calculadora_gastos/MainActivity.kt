package com.axchisan.calculadora_gastos

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/**
 * Puente entre la aplicación y las capturas de pago que recoge
 * [EscuchaDeNotificaciones].
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(motor: FlutterEngine) {
        super.configureFlutterEngine(motor)

        MethodChannel(motor.dartExecutor.binaryMessenger, CANAL).setMethodCallHandler {
            llamada, respuesta ->
            when (llamada.method) {
                "permisoConcedido" -> respuesta.success(tienePermiso())
                "abrirAjustes" -> {
                    abrirAjustesDeNotificaciones()
                    respuesta.success(null)
                }
                "capturas" -> respuesta.success(capturas())
                "descartar" -> {
                    descartar(llamada.arguments as List<*>)
                    respuesta.success(null)
                }
                else -> respuesta.notImplemented()
            }
        }
    }

    /**
     * Comprueba si el usuario concedió el acceso a las notificaciones.
     *
     * No hay una API directa: Android guarda los servicios autorizados en un ajuste seguro y
     * hay que buscar el nuestro dentro de esa lista.
     */
    private fun tienePermiso(): Boolean {
        val autorizados = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return autorizados.contains(packageName)
    }

    /**
     * Lleva a la pantalla del sistema donde se concede el permiso.
     *
     * No se puede pedir con un diálogo como el resto de permisos: es un acceso amplio y Android
     * obliga a concederlo a mano en Ajustes.
     */
    private fun abrirAjustesDeNotificaciones() {
        startActivity(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    private fun capturas(): List<Map<String, Any?>> {
        val guardadas = getSharedPreferences(
            EscuchaDeNotificaciones.ALMACEN,
            MODE_PRIVATE,
        ).getString(EscuchaDeNotificaciones.CLAVE, "[]")

        val lista = JSONArray(guardadas)
        return (0 until lista.length()).map { i ->
            val fila = lista.getJSONObject(i)
            mapOf(
                "id" to fila.optString("id"),
                "paquete" to fila.optString("paquete"),
                "titulo" to fila.optString("titulo"),
                "texto" to fila.optString("texto"),
                "instante" to fila.optLong("instante"),
            )
        }
    }

    /** Quita de la lista las capturas ya resueltas, se hayan registrado o descartado. */
    private fun descartar(ids: List<*>) {
        val preferencias = getSharedPreferences(
            EscuchaDeNotificaciones.ALMACEN,
            MODE_PRIVATE,
        )
        val actuales = JSONArray(
            preferencias.getString(EscuchaDeNotificaciones.CLAVE, "[]")
        )

        val quedan = JSONArray()
        for (i in 0 until actuales.length()) {
            val fila = actuales.getJSONObject(i)
            if (fila.optString("id") !in ids) quedan.put(fila)
        }

        preferencias.edit()
            .putString(EscuchaDeNotificaciones.CLAVE, quedan.toString())
            .apply()
    }

    private companion object {
        const val CANAL = "com.axchisan.calculadora_gastos/capturas"
    }
}
