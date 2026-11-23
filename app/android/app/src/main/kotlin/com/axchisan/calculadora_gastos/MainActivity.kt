package com.axchisan.calculadora_gastos

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
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

    /** El PDF que se compartió con la aplicación y que Flutter aún no ha recogido. */
    private var pdfPendiente: ByteArray? = null

    private var canalExtractos: MethodChannel? = null

    /** La respuesta que espera el permiso de leer SMS. */
    private var permisoSmsPendiente: MethodChannel.Result? = null

    /** La respuesta que espera el PDF elegido con el selector de documentos. */
    private var eleccionPendiente: MethodChannel.Result? = null

    override fun onCreate(estado: android.os.Bundle?) {
        super.onCreate(estado)
        abiertaDesdeElAviso = intent?.getBooleanExtra(
            EscuchaDeNotificaciones.EXTRA_BANDEJA, false,
        ) ?: false
        recogerPdf(intent)
    }

    /** Con la aplicación ya abierta, tocar el aviso llega por aquí y no por onCreate. */
    override fun onNewIntent(nuevo: Intent) {
        super.onNewIntent(nuevo)
        if (nuevo.getBooleanExtra(EscuchaDeNotificaciones.EXTRA_BANDEJA, false)) {
            abiertaDesdeElAviso = true
        }
        if (recogerPdf(nuevo)) canalExtractos?.invokeMethod("pdfRecibido", null)
    }

    private fun tienePermisoSms(): Boolean =
        PERMISOS_SMS.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    override fun onRequestPermissionsResult(
        codigo: Int, permisos: Array<out String>, resultados: IntArray,
    ) {
        super.onRequestPermissionsResult(codigo, permisos, resultados)
        if (codigo != CODIGO_PERMISO_SMS) return
        permisoSmsPendiente?.success(tienePermisoSms())
        permisoSmsPendiente = null
    }

    /**
     * Los SMS del banco desde una fecha, del más viejo al más reciente, para empezar con datos.
     * Solo se leen los remitentes del banco; el resto de SMS ni se toca.
     */
    private fun historialDelBanco(desde: Long): List<Map<String, Any>> {
        if (!tienePermisoSms()) return emptyList()
        val resultado = mutableListOf<Map<String, Any>>()
        contentResolver.query(
            android.provider.Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf("address", "body", "date"),
            "date >= ?",
            arrayOf(desde.toString()),
            "date ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                val remitente = c.getString(0)
                val texto = c.getString(1) ?: continue
                if (EnvioDeAvisos.esDelBanco(remitente, texto)) {
                    resultado.add(mapOf("texto" to texto, "fecha" to c.getLong(2)))
                }
            }
        }
        return resultado
    }

    @Deprecated("Basta para un único selector; no hace falta la API de resultados")
    override fun onActivityResult(codigo: Int, resultado: Int, datos: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(codigo, resultado, datos)
        if (codigo != CODIGO_ELEGIR_PDF) return
        val respuesta = eleccionPendiente ?: return
        eleccionPendiente = null
        val uri = datos?.data
        if (resultado != RESULT_OK || uri == null) {
            respuesta.success(null)
            return
        }
        val bytes = try {
            contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            null
        }
        respuesta.success(if (bytes != null && bytes.size <= MAXIMO_PDF) bytes else null)
    }

    /**
     * Lee el PDF que llega con «Compartir» o «Abrir con». Se lee aquí y no después porque el
     * permiso para leer el archivo dura lo que dura la actividad que lo recibió.
     */
    private fun recogerPdf(recibido: Intent?): Boolean {
        if (recibido == null) return false
        val uri: android.net.Uri? = when (recibido.action) {
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33) {
                recibido.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                recibido.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            Intent.ACTION_VIEW -> recibido.data
            else -> null
        }
        if (uri == null) return false
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            // Un extracto pesa unos cientos de KB; algo enorme no es lo que se espera.
            if (bytes == null || bytes.size > MAXIMO_PDF) return false
            pdfPendiente = bytes
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onResume() {
        super.onResume()
        // Lo que no se pudo enviar al llegar el SMS (sin red, en reposo) sale al abrir la app.
        if (EnvioDeAvisos.activo(this)) {
            kotlin.concurrent.thread { EnvioDeAvisos.enviarPendientes(applicationContext) }
        }
        // Abrir la aplicación es el momento natural para recuperar el servicio si el sistema lo
        // soltó. No cuesta nada si ya está enganchado.
        if (tienePermiso()) EscuchaDeNotificaciones.pedirReconexion(this)
    }

    override fun configureFlutterEngine(motor: FlutterEngine) {
        super.configureFlutterEngine(motor)

        MethodChannel(motor.dartExecutor.binaryMessenger, CANAL_SMS).setMethodCallHandler {
            llamada, respuesta ->
            when (llamada.method) {
                "estado" -> respuesta.success(mapOf(
                    "permiso" to tienePermisoSms(),
                    "activo" to EnvioDeAvisos.activo(this),
                    "pendientes" to EnvioDeAvisos.pendientes(this),
                    "ultimoEnvio" to EnvioDeAvisos.ultimoEnvio(this),
                ))
                "pedirPermiso" -> {
                    if (tienePermisoSms()) {
                        respuesta.success(true)
                    } else {
                        permisoSmsPendiente?.success(false)
                        permisoSmsPendiente = respuesta
                        ActivityCompat.requestPermissions(this, PERMISOS_SMS, CODIGO_PERMISO_SMS)
                    }
                }
                "configurar" -> {
                    EnvioDeAvisos.configurar(
                        this, llamada.argument<String>("url"), llamada.argument<String>("clave"),
                    )
                    respuesta.success(null)
                }
                "historial" -> {
                    val desde = (llamada.argument<Number>("desde") ?: 0).toLong()
                    kotlin.concurrent.thread {
                        val lista = try {
                            historialDelBanco(desde)
                        } catch (e: Exception) {
                            emptyList()
                        }
                        runOnUiThread { respuesta.success(lista) }
                    }
                }
                else -> respuesta.notImplemented()
            }
        }

        canalExtractos = MethodChannel(motor.dartExecutor.binaryMessenger, CANAL_EXTRACTOS).also {
            it.setMethodCallHandler { llamada, respuesta ->
                when (llamada.method) {
                    "tomarPdf" -> {
                        respuesta.success(pdfPendiente)
                        pdfPendiente = null
                    }
                    "elegirPdf" -> {
                        eleccionPendiente?.success(null)
                        eleccionPendiente = respuesta
                        val elegir = Intent(Intent.ACTION_OPEN_DOCUMENT)
                            .addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("application/pdf")
                        @Suppress("DEPRECATION")
                        startActivityForResult(elegir, CODIGO_ELEGIR_PDF)
                    }
                    else -> respuesta.notImplemented()
                }
            }
        }

        MethodChannel(motor.dartExecutor.binaryMessenger, CANAL).setMethodCallHandler {
            llamada, respuesta ->
            when (llamada.method) {
                "permisoConcedido" -> respuesta.success(tienePermiso())
                "abrirAjustes" -> {
                    abrirAjustesDeNotificaciones()
                    respuesta.success(null)
                }
                "instalacionLateral" -> respuesta.success(esInstalacionLateral())
                "estado" -> respuesta.success(estado())
                "vigilante" -> {
                    val encender = llamada.arguments as? Boolean ?: false
                    ServicioVigilante.recordarEleccion(this, encender)
                    if (encender) {
                        ServicioVigilante.encender(this)
                    } else {
                        ServicioVigilante.apagar(this)
                    }
                    respuesta.success(null)
                }
                "reconectar" -> {
                    EscuchaDeNotificaciones.pedirReconexion(this)
                    respuesta.success(null)
                }
                "probarAviso" -> {
                    EscuchaDeNotificaciones.publicarAviso(
                        this,
                        "Prueba · si ves esto, los avisos funcionan",
                    )
                    respuesta.success(null)
                }
                "abrirAjustesDeBateria" -> {
                    abrirAjustesDeBateria()
                    respuesta.success(null)
                }
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

    /**
     * Cómo está de verdad la captura de pagos.
     *
     * Distingue lo que Android muestra como un solo interruptor pero son dos cosas: que el
     * permiso esté concedido y que el servicio esté **enganchado**. Puede estar lo primero sin
     * lo segundo —los fabricantes con gestión agresiva de batería matan el proceso y Android no
     * siempre lo vuelve a conectar—, y en ese estado no llega ni una captura sin que nada avise.
     */
    private fun estado(): Map<String, Any?> {
        val preferencias = getSharedPreferences(
            EscuchaDeNotificaciones.ALMACEN,
            MODE_PRIVATE,
        )
        val conectadoDesde = preferencias.getLong(
            EscuchaDeNotificaciones.CLAVE_CONECTADO, 0,
        )

        return mapOf(
            "permiso" to tienePermiso(),
            "conectadoDesde" to if (conectadoDesde == 0L) null else conectadoDesde,
            "capturas" to capturas().size,
            "avisosPermitidos" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "bateriaLibre" to sinRestriccionDeBateria(),
            "vigilante" to ServicioVigilante.estaEncendido(this),
        )
    }

    /**
     * Si el sistema deja a la aplicación funcionar en segundo plano sin restricciones.
     *
     * Con la batería optimizada, el fabricante puede matar el servicio y dejar de entregarle
     * notificaciones. Es la causa más habitual de que la captura funcione un rato y luego deje
     * de hacerlo sin motivo aparente.
     */
    private fun sinRestriccionDeBateria(): Boolean {
        val energia = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        return energia.isIgnoringBatteryOptimizations(packageName)
    }

    private fun abrirAjustesDeBateria() {
        startActivity(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
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
        const val CANAL_EXTRACTOS = "com.axchisan.calculadora_gastos/extractos"
        const val CODIGO_ELEGIR_PDF = 4127
        const val CANAL_SMS = "com.axchisan.calculadora_gastos/sms"
        const val CODIGO_PERMISO_SMS = 4128
        val PERMISOS_SMS = arrayOf(
            android.Manifest.permission.RECEIVE_SMS,
            android.Manifest.permission.READ_SMS,
        )
        // Viaja en base64 dentro del JSON y Lambda acepta hasta 6 MB por petición.
        const val MAXIMO_PDF = 4 * 1024 * 1024

        /** Instaladores que Android considera una tienda y no dejan el ajuste restringido. */
        val TIENDAS = setOf(
            "com.android.vending",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
        )
    }
}
