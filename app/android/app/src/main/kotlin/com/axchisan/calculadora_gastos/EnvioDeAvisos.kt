package com.axchisan.calculadora_gastos

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Envía a la API los avisos del banco que llegan por SMS, con la clave de ingesta del teléfono.
 *
 * Lo que no se puede enviar (sin red, el teléfono en reposo) queda en una cola y se reintenta
 * con el siguiente SMS o al abrir la aplicación. Solo se guardan los SMS del banco, nunca otros.
 */
object EnvioDeAvisos {

    private const val PREFERENCIAS = "ingesta_avisos"
    private const val URL_API = "url"
    private const val CLAVE = "clave"
    private const val COLA = "cola"
    private const val ULTIMO_ENVIO = "ultimo_envio"
    private const val MAXIMO_EN_COLA = 500

    /** Remitentes cortos de Bancolombia; el 87400 avisa los pagos con QR. */
    private val REMITENTES = setOf("85540", "85784", "85630", "87400")

    fun configurar(contexto: Context, url: String?, clave: String?) {
        contexto.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE).edit().apply {
            if (url == null || clave == null) {
                remove(URL_API)
                remove(CLAVE)
                remove(COLA)
            } else {
                putString(URL_API, url.trimEnd('/'))
                putString(CLAVE, clave)
            }
        }.apply()
    }

    fun activo(contexto: Context): Boolean =
        contexto.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE).getString(CLAVE, null) != null

    fun pendientes(contexto: Context): Int =
        leerCola(contexto).length()

    fun ultimoEnvio(contexto: Context): Long =
        contexto.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE).getLong(ULTIMO_ENVIO, 0)

    /** Si un SMS es del banco: por el remitente o porque empieza como sus avisos. */
    fun esDelBanco(remitente: String?, texto: String): Boolean =
        (remitente != null && remitente in REMITENTES) || texto.trimStart().startsWith("Bancolombia")

    /** Guarda el aviso en la cola y trata de enviar todo lo pendiente. Bloquea: no en el hilo principal. */
    fun recibir(contexto: Context, texto: String) {
        if (!activo(contexto)) return
        synchronized(this) {
            val cola = leerCola(contexto)
            if (cola.length() >= MAXIMO_EN_COLA) cola.remove(0)
            cola.put(texto)
            guardarCola(contexto, cola)
        }
        enviarPendientes(contexto)
    }

    /** Envía lo que esté en la cola. Bloquea: no en el hilo principal. */
    fun enviarPendientes(contexto: Context) {
        val preferencias = contexto.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE)
        val url = preferencias.getString(URL_API, null) ?: return
        val clave = preferencias.getString(CLAVE, null) ?: return
        val cola = synchronized(this) { leerCola(contexto) }
        if (cola.length() == 0) return

        val avisos = JSONArray()
        val cuantos = minOf(cola.length(), 200)
        for (i in 0 until cuantos) {
            avisos.put(JSONObject().put("origen", "SMS").put("texto", cola.getString(i)))
        }
        val cuerpo = JSONObject().put("avisos", avisos).toString().toByteArray(Charsets.UTF_8)

        val codigo = try {
            val conexion = URL("$url/api/ingesta/avisos").openConnection() as HttpURLConnection
            conexion.requestMethod = "POST"
            conexion.connectTimeout = 15_000
            conexion.readTimeout = 30_000
            conexion.doOutput = true
            conexion.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conexion.setRequestProperty("X-Clave-Ingesta", clave)
            conexion.outputStream.use { it.write(cuerpo) }
            val c = conexion.responseCode
            conexion.disconnect()
            c
        } catch (e: Exception) {
            return // Sin red: se queda en la cola.
        }

        when {
            codigo in 200..299 -> {
                synchronized(this) {
                    // Lo que llegó mientras se enviaba se conserva.
                    val actual = leerCola(contexto)
                    val resto = JSONArray()
                    for (i in cuantos until actual.length()) resto.put(actual.getString(i))
                    guardarCola(contexto, resto)
                }
                preferencias.edit().putLong(ULTIMO_ENVIO, System.currentTimeMillis()).apply()
                if (cola.length() > cuantos) enviarPendientes(contexto)
            }
            // La clave se revocó: no tiene sentido seguir acumulando.
            codigo == 401 -> configurar(contexto, null, null)
            // Un 400 no se arregla reintentando: se descarta el lote para no atascar la cola.
            codigo in 400..499 -> synchronized(this) {
                val actual = leerCola(contexto)
                val resto = JSONArray()
                for (i in cuantos until actual.length()) resto.put(actual.getString(i))
                guardarCola(contexto, resto)
            }
        }
    }

    private fun leerCola(contexto: Context): JSONArray = try {
        JSONArray(
            contexto.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE).getString(COLA, "[]"),
        )
    } catch (e: Exception) {
        JSONArray()
    }

    private fun guardarCola(contexto: Context, cola: JSONArray) {
        contexto.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE).edit()
            .putString(COLA, cola.toString()).apply()
    }
}
