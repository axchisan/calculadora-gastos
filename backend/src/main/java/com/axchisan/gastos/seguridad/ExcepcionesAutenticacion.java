package com.axchisan.gastos.seguridad;

/** Errores del proceso de autenticación. */
public final class ExcepcionesAutenticacion {

    private ExcepcionesAutenticacion() {
    }

    /**
     * Credenciales incorrectas.
     *
     * <p>Se lanza tanto si el correo no existe como si la contraseña no coincide: distinguir
     * ambos casos permitiría averiguar qué correos están registrados.
     */
    public static class CredencialesInvalidas extends RuntimeException {
        public CredencialesInvalidas() {
            super("Correo o contraseña incorrectos");
        }
    }

    /** El correo ya tiene una cuenta asociada. */
    public static class EmailYaRegistrado extends RuntimeException {
        public EmailYaRegistrado() {
            super("Ya existe una cuenta con ese correo");
        }
    }

    /**
     * No se admiten cuentas nuevas.
     *
     * <p>La aplicación es de uso personal: la primera cuenta se crea sola al arrancar con la
     * base vacía y, a partir de ahí, el registro queda cerrado.
     */
    public static class RegistroCerrado extends RuntimeException {
        public RegistroCerrado() {
            super("El registro de nuevas cuentas está cerrado");
        }
    }

    /** El token de refresco no existe, caducó o fue revocado. */
    public static class TokenInvalido extends RuntimeException {
        public TokenInvalido(String mensaje) {
            super(mensaje);
        }
    }

    /** Se superó el número de intentos permitidos. */
    public static class DemasiadosIntentos extends RuntimeException {
        private final long segundosEspera;

        public DemasiadosIntentos(long segundosEspera) {
            super("Demasiados intentos fallidos. Intenta de nuevo en " + segundosEspera
                    + " segundos");
            this.segundosEspera = segundosEspera;
        }

        public long getSegundosEspera() {
            return segundosEspera;
        }
    }
}
