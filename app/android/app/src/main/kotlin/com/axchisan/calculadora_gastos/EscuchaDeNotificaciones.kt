package com.axchisan.calculadora_gastos

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Guarda las notificaciones de pago que publica el teléfono y avisa de cada compra detectada.
 *
 * Es la única forma de enterarse de lo que se paga: Google Wallet no expone ninguna API para
 * consultarlo, y Android no deja que una aplicación observe el servicio de pago. Lo que sí se
 * puede leer es la notificación que aparece en pantalla.
 *
 * Este servicio hace deliberadamente lo mínimo: filtra, guarda el texto tal cual y publica un
 * aviso. Interpretar el importe y el comercio se hace en Dart, donde puede probarse contra
 * textos reales sin arrancar un teléfono.
 */
class EscuchaDeNotificaciones : NotificationListenerService() {

    /**
     * El sistema acaba de enganchar el servicio. Se deja constancia de cuándo.
     *
     * Sin esta marca no había forma de saber desde la aplicación si el servicio estaba vivo o
     * si Android lo tenía «habilitado» pero sin conectar, que son dos cosas distintas y solo la
     * segunda explica que no llegue ninguna captura.
     */
    override fun onListenerConnected() {
        super.onListenerConnected()
        getSharedPreferences(ALMACEN, MODE_PRIVATE).edit()
            .putLong(CLAVE_CONECTADO, System.currentTimeMillis())
            .apply()
    }

    /**
     * El sistema soltó el servicio. Se pide volver a engancharlo.
     *
     * Pasa más de lo que debería: los fabricantes con gestión agresiva de batería matan el
     * proceso y Android no siempre lo vuelve a conectar por su cuenta. Pedirlo explícitamente
     * es la forma que da la propia API de recuperarse.
     */
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        getSharedPreferences(ALMACEN, MODE_PRIVATE).edit()
            .remove(CLAVE_CONECTADO)
            .apply()
        requestRebind(ComponentName(this, EscuchaDeNotificaciones::class.java))
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!esDeInteres(sbn.packageName)) return

        val extras = sbn.notification.extras
        val titulo = extras.getCharSequence("android.title")?.toString().orEmpty()
        val texto = extras.getCharSequence("android.text")?.toString().orEmpty()

        // Sin importe no hay nada que registrar. La comprobación es a propósito grosera —basta
        // con que haya un dígito— porque decidir si es un pago le toca a Dart.
        if (titulo.isBlank() && texto.isBlank()) return
        if (!texto.any { it.isDigit() } && !titulo.any { it.isDigit() }) return

        // La aplicación de mensajes trae toda la conversación del usuario, no solo avisos del
        // banco. Aquí se descarta lo que no lo parezca **antes de escribir nada en disco**: los
        // mensajes personales no tienen por qué acabar guardados en ningún sitio.
        if (esMensajeria(sbn.packageName) && !pareceAvisoDeBanco(texto)) return

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

        if (!yaSeAviso(texto)) publicarAviso(this, resumir(titulo, texto))
    }

    private fun esDeInteres(paquete: String): Boolean =
        PAQUETES_VIGILADOS.any { paquete.contains(it) }

    private fun esMensajeria(paquete: String): Boolean =
        MENSAJERIA.any { paquete.contains(it) }

    /**
     * Reconoce un SMS de banco entre el resto de mensajes.
     *
     * Se exige que aparezca el nombre del banco **y** una palabra de movimiento. Con solo una de
     * las dos, un mensaje de alguien contando que compró algo entraría en la bandeja; con
     * ninguna, entraría media conversación.
     */
    private fun pareceAvisoDeBanco(texto: String): Boolean {
        val minusculas = texto.lowercase()
        return BANCOS.any { minusculas.contains(it) } &&
            MOVIMIENTOS.any { minusculas.contains(it) }
    }

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

    // --- aviso propio ---

    /** Lo que se enseña en el aviso: el título si dice algo, y si no la primera frase. */
    private fun resumir(titulo: String, texto: String): String {
        // El SMS del banco arrastra una cola de teléfonos de contacto que no aporta nada.
        val primeraFrase = texto.substringBefore(". ").trim()
        val cuerpo = if (primeraFrase.length in 1..160) primeraFrase else texto.take(160)

        // El título del SMS es el número corto del remitente y no dice nada; el de la billetera
        // y el del banco sí son el comercio o el importe.
        return if (titulo.isBlank() || titulo.all { it.isDigit() }) cuerpo else "$titulo · $cuerpo"
    }

    /**
     * Evita avisar dos veces de la misma compra.
     *
     * Al pagar con el teléfono llegan dos notificaciones, la de la billetera y la del banco.
     * Se comparan **solo los dígitos del importe**, sin interpretarlos: da igual que uno escriba
     * 54,670.00 y el otro 54.670,00, porque quitando los separadores los dos dan 5467000.
     */
    private fun yaSeAviso(texto: String): Boolean {
        val importe = Regex("[\\d.,]{3,}").find(texto)?.value
            ?.replace(Regex("[.,]"), "")
            ?: return false

        val preferencias = getSharedPreferences(ALMACEN, MODE_PRIVATE)
        val anterior = preferencias.getString(CLAVE_ULTIMO_AVISO, null)
        val ahora = System.currentTimeMillis()

        if (anterior != null) {
            val partes = anterior.split("@")
            if (partes.size == 2 && partes[0] == importe) {
                val cuando = partes[1].toLongOrNull() ?: 0
                if (ahora - cuando < VENTANA_DUPLICADO) return true
            }
        }

        preferencias.edit().putString(CLAVE_ULTIMO_AVISO, "$importe@$ahora").apply()
        return false
    }

    companion object {
        const val ALMACEN = "capturas_de_pago"
        const val CLAVE_CONECTADO = "conectado_desde"
        const val CLAVE = "pendientes"
        const val EXTRA_BANDEJA = "abrir_bandeja"

        private const val CLAVE_ULTIMO_AVISO = "ultimo_aviso"
        private const val CANAL_AVISOS = "pagos_detectados"
        private const val MAXIMO = 200

        /** Al pagar con el teléfono llegan dos avisos con segundos de diferencia. */
        private const val VENTANA_DUPLICADO = 5 * 60 * 1000L

        /**
         * Aplicaciones cuyas notificaciones se miran.
         *
         * Google Wallet cubre lo que se paga acercando el teléfono. La del banco llega además
         * con la tarjeta física y en las compras por internet. Y la de mensajes trae los SMS del
         * banco, que son los únicos que avisan de una compra en la que el teléfono no interviene
         * para nada, como una máquina expendedora.
         */
        val PAQUETES_VIGILADOS = listOf(
            "walletnfcrel",
            "nu.production",
            "bancolombia",
            "apps.messaging",
        )

        /** De estas hay que filtrar por contenido: traen también los mensajes personales. */
        val MENSAJERIA = listOf("apps.messaging")

        val BANCOS = listOf("bancolombia", "nequi", "davivienda", "bbva", "scotiabank")

        val MOVIMIENTOS = listOf("compraste", "compra por", "pagaste", "retiraste", "transferiste")

        /**
         * Publica el aviso de que hay una compra por apuntar.
         *
         * Vive en el companion para que la aplicación pueda usar el mismo camino al probar el
         * aviso: si la prueba llega, el problema está en la captura, y si no llega, en los
         * permisos. Sin eso, diagnosticar por qué no aparece nada es adivinar.
         */
        fun publicarAviso(contexto: Context, resumen: String) {
            val gestor = NotificationManagerCompat.from(contexto)
            if (!gestor.areNotificationsEnabled()) return

            crearCanal(contexto)

            val abrirLaApp = PendingIntent.getActivity(
                contexto,
                0,
                Intent(contexto, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    .putExtra(EXTRA_BANDEJA, true),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val aviso = NotificationCompat.Builder(contexto, CANAL_AVISOS)
                // El icono pequeño tiene que ser una silueta propia: Android lo tiñe y descarta
                // todo menos el canal alfa.
                .setSmallIcon(R.drawable.ic_aviso)
                .setContentTitle("Compra detectada")
                .setContentText(resumen)
                .setStyle(NotificationCompat.BigTextStyle().bigText(resumen))
                .setContentIntent(abrirLaApp)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .build()

            try {
                gestor.notify(resumen.hashCode(), aviso)
            } catch (e: SecurityException) {
                // Sin permiso para publicar. La captura ya quedó guardada, así que la compra
                // sigue apareciendo en la aplicación al abrirla.
            }
        }

        private fun crearCanal(contexto: Context) {
            val canal = NotificationChannel(
                CANAL_AVISOS,
                "Compras detectadas",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Avisa de los pagos del teléfono para apuntarlos de un toque"
                setShowBadge(true)
            }
            val gestor = contexto.getSystemService(Context.NOTIFICATION_SERVICE)
            (gestor as NotificationManager).createNotificationChannel(canal)
        }

        /**
         * Pide a Android que vuelva a enganchar el servicio si lo tiene suelto.
         *
         * Se hacen dos cosas porque una sola no siempre basta. `requestRebind` es la vía que da
         * la API, pero solo surte efecto si el sistema llegó a conectar el servicio alguna vez.
         * Apagar y encender el componente obliga a Android a reevaluarlo desde cero, y es lo que
         * lo recupera cuando quedó habilitado pero sin conectar nunca —el estado en el que no
         * llega ni una captura y nada lo advierte.
         */
        fun pedirReconexion(contexto: Context) {
            val componente = ComponentName(contexto, EscuchaDeNotificaciones::class.java)

            contexto.packageManager.apply {
                setComponentEnabledSetting(
                    componente,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
                setComponentEnabledSetting(
                    componente,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }

            requestRebind(componente)
        }
    }
}
