package com.axchisan.calculadora_gastos

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Mantiene vivo el proceso para que la escucha de notificaciones no se caiga.
 *
 * Los fabricantes con gestión agresiva de batería —Honor entre ellos— matan los procesos en
 * segundo plano, y cuando eso le pasa a la escucha de notificaciones el sistema no siempre la
 * vuelve a conectar. El síntoma es el peor posible: la detección funciona si la aplicación está
 * abierta y no funciona si no lo está, sin ningún patrón visible.
 *
 * Un servicio en primer plano es lo único que Android garantiza que no se mata sin más. El
 * precio es una notificación permanente, y por eso **esto es opcional**: se enciende desde la
 * aplicación y se puede apagar. Sin él la detección sigue funcionando, pero a ratos.
 */
class ServicioVigilante : Service() {

    private val reloj = Handler(Looper.getMainLooper())

    /**
     * Repite la petición de reconexión cada cierto tiempo.
     *
     * Es un cinturón además de los tirantes: si aun con el servicio en primer plano el sistema
     * llegara a soltar la escucha, esto la recupera sin esperar a que se abra la aplicación.
     */
    private val reconectar = object : Runnable {
        override fun run() {
            EscuchaDeNotificaciones.pedirReconexion(this@ServicioVigilante)
            reloj.postDelayed(this, CADA_CUANTO_RECONECTA)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == PARAR) {
            apagar()
            return START_NOT_STICKY
        }

        startForeground(ID_AVISO, construirAviso())
        reloj.removeCallbacks(reconectar)
        reloj.post(reconectar)

        // START_STICKY: si el sistema acaba matando el proceso, que lo vuelva a levantar.
        return START_STICKY
    }

    override fun onDestroy() {
        reloj.removeCallbacks(reconectar)
        super.onDestroy()
    }

    private fun apagar() {
        reloj.removeCallbacks(reconectar)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * La notificación permanente.
     *
     * Va en un canal de importancia mínima para que no suene, no vibre y quede recogida al final
     * de la lista. Es el peaje de tener la detección siempre despierta, y conviene que moleste
     * lo menos posible.
     */
    private fun construirAviso(): android.app.Notification {
        val gestor = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        gestor.createNotificationChannel(
            NotificationChannel(CANAL, "Detección activa", NotificationManager.IMPORTANCE_MIN)
                .apply {
                    description = "Mantiene despierta la lectura de las notificaciones de pago"
                    setShowBadge(false)
                }
        )

        val abrir = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CANAL)
            .setSmallIcon(R.drawable.ic_aviso)
            .setContentTitle("Detectando pagos")
            .setContentText("Tus compras se apuntan solas")
            .setContentIntent(abrir)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    companion object {
        private const val CANAL = "vigilancia_pagos"
        private const val ID_AVISO = 1
        private const val PARAR = "parar"

        private const val CADA_CUANTO_RECONECTA = 15 * 60 * 1000L

        fun encender(contexto: Context) {
            val intencion = Intent(contexto, ServicioVigilante::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                contexto.startForegroundService(intencion)
            } else {
                contexto.startService(intencion)
            }
        }

        fun apagar(contexto: Context) {
            contexto.startService(
                Intent(contexto, ServicioVigilante::class.java).setAction(PARAR)
            )
        }

        /** Si el usuario lo dejó encendido. Se guarda para poder recuperarlo tras un reinicio. */
        fun estaEncendido(contexto: Context): Boolean =
            contexto.getSharedPreferences(EscuchaDeNotificaciones.ALMACEN, MODE_PRIVATE)
                .getBoolean(CLAVE, false)

        fun recordarEleccion(contexto: Context, encendido: Boolean) {
            contexto.getSharedPreferences(EscuchaDeNotificaciones.ALMACEN, MODE_PRIVATE)
                .edit()
                .putBoolean(CLAVE, encendido)
                .apply()
        }

        private const val CLAVE = "vigilante_encendido"
    }
}
