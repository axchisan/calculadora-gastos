package com.axchisan.calculadora_gastos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Vuelve a enganchar la escucha de notificaciones cuando arranca el teléfono.
 *
 * Sin esto había que abrir la aplicación para que el servicio se conectara, y cualquier compra
 * hecha antes de hacerlo se perdía. Un teléfono se reinicia y el usuario no tiene por qué
 * acordarse de abrir nada.
 */
class ReconexionAlArrancar : BroadcastReceiver() {

    override fun onReceive(contexto: Context, intencion: Intent) {
        if (intencion.action !in ACCIONES) return

        // Solo tiene sentido si el usuario concedió el acceso; si no, no hay nada que reenganchar.
        val autorizados = android.provider.Settings.Secure.getString(
            contexto.contentResolver,
            "enabled_notification_listeners",
        ) ?: return

        if (!autorizados.contains(contexto.packageName)) return

        EscuchaDeNotificaciones.pedirReconexion(contexto)

        // Y se recupera el vigilante si el usuario lo tenía encendido: un reinicio no debería
        // apagar en silencio algo que se dejó activado a propósito.
        if (ServicioVigilante.estaEncendido(contexto)) {
            ServicioVigilante.encender(contexto)
        }
    }

    private companion object {
        val ACCIONES = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            // Algunos fabricantes usan este en lugar del estándar.
            "android.intent.action.QUICKBOOT_POWERON",
            // Tras actualizar la aplicación, el servicio queda suelto igual que tras un arranque.
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }
}
