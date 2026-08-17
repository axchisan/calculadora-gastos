package com.axchisan.gastos.dominio;

/** Cómo llegó una compra al registro. */
public enum OrigenCompra {

    /** La escribió el usuario. */
    MANUAL,

    /** La capturó la aplicación de Android de una notificación de pago del teléfono. */
    NOTIFICACION
}
