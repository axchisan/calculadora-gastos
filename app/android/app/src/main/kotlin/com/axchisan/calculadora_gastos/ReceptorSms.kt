package com.axchisan.calculadora_gastos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import kotlin.concurrent.thread

/**
 * Recibe cada SMS al llegar, aunque la aplicación esté cerrada, y reenvía los del banco.
 *
 * Es más fiable que leer notificaciones: Android despierta la aplicación para cada SMS y el
 * texto llega completo. Los SMS largos llegan en varias partes del mismo remitente; se unen.
 */
class ReceptorSms : BroadcastReceiver() {

    override fun onReceive(contexto: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!EnvioDeAvisos.activo(contexto)) return
        val mensajes = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val porRemitente = linkedMapOf<String, StringBuilder>()
        for (m in mensajes) {
            val remitente = m.displayOriginatingAddress ?: m.originatingAddress ?: ""
            porRemitente.getOrPut(remitente) { StringBuilder() }.append(m.messageBody ?: "")
        }
        val delBanco = porRemitente.filter { (remitente, texto) ->
            EnvioDeAvisos.esDelBanco(remitente, texto.toString())
        }
        if (delBanco.isEmpty()) return

        // El envío usa la red: fuera del hilo principal y con el receptor vivo hasta terminar.
        val pendiente = goAsync()
        thread {
            try {
                delBanco.values.forEach { EnvioDeAvisos.recibir(contexto, it.toString()) }
            } finally {
                pendiente.finish()
            }
        }
    }
}
