package com.axchisan.calculadora_gastos

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/**
 * Puente entre la aplicación y las capturas de pago que recoge
 * [EscuchaDeNotificaciones].
 */
class MainActivity : FlutterActivity() {

    /** Cierto cuando la aplicación se abrió tocando el aviso de una compra detectada. */
    private var abiertaDesdeElAviso = false

    override fun onCreate(estado: android.os.Bundle?) {
        super.onCreate(estado)
        abiertaDesdeElAviso = intent?.getBooleanExtra(
            EscuchaDeNotificaciones.EXTRA_BANDEJA, false,
        ) ?: false
    }

    /** Con la aplicación ya abierta, tocar el aviso llega por aquí y no por onCreate. */
    override fun onNewIntent(nuevo: Intent) {
        super.onNewIntent(nuevo)
        if (nuevo.getBooleanExtra(EscuchaDeNotificaciones.EXTRA_BANDEJA, false)) {
            abiertaDesdeElAviso = true
        }
    }

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
                "instalacionLateral" -> respuesta.success(esInstalacionLateral())
                "pedirPermisoDeAvisos" -> {
                    pedirPermisoDeAvisos()
                    respuesta.success(null)
                }
                // Se consume: la aplicación solo debe saltar a la bandeja la primera vez que
                // se pregunta tras abrirla desde el aviso, no en cada recarga de la pantalla.
                "abriDesdeElAviso" -> {
                    respuesta.success(abiertaDesdeElAviso)
                    abiertaDesdeElAviso = false
                }
                "abrirInfoDeLaApp" -> {
                    abrirInfoDeLaApp()
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

    /**
     * Indica si la aplicación se instaló desde un APK suelto y no desde una tienda.
     *
     * Importa porque Android 13 bloquea el acceso a notificaciones en ese caso: marca el ajuste
     * como restringido y deja el interruptor apagado sin explicar por qué. Saberlo permite
     * contarle al usuario el paso que le falta en lugar de dejarlo mirando un interruptor
     * muerto.
     */
    private fun esInstalacionLateral(): Boolean {
        val instalador = try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                packageManager.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
        } catch (e: Exception) {
            null
        }

        // Sin instalador registrado, el APK se abrió a mano. Los paquetes de tiendas conocidas
        // sí quedan anotados y no arrastran la restricción.
        return instalador == null || instalador !in TIENDAS
    }

    /**
     * Abre la ficha de la aplicación en Ajustes.
     *
     * Es donde vive el menú de tres puntos con «Permitir ajustes restringidos», que es el paso
     * que desbloquea el acceso a notificaciones. Llevar ahí directamente evita que haya que
     * buscarlo entre todas las aplicaciones del teléfono.
     */
    private fun abrirInfoDeLaApp() {
        startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                android.net.Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /**
     * Pide el permiso de publicar avisos, obligatorio desde Android 13.
     *
     * Sin él, el servicio detecta las compras igual y las guarda, pero no puede avisar: habría
     * que abrir la aplicación para enterarse, que es justo lo que se quería evitar.
     */
    private fun pedirPermisoDeAvisos() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        val permiso = "android.permission.POST_NOTIFICATIONS"
        if (checkSelfPermission(permiso) == PackageManager.PERMISSION_GRANTED) return

        ActivityCompat.requestPermissions(this, arrayOf(permiso), 1)
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

        /** Instaladores que Android considera una tienda y no dejan el ajuste restringido. */
        val TIENDAS = setOf(
            "com.android.vending",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
        )
    }
}
