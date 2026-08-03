/// Configuración que cambia entre entornos.
class Configuracion {
  const Configuracion._();

  /// Dirección de la API.
  ///
  /// Se inyecta al compilar con `--dart-define=API_URL=...`. El valor por defecto apunta al
  /// backend en local, que es lo habitual durante el desarrollo.
  static const String urlApi = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Margen para renovar el token de acceso antes de que caduque, de modo que una petición no
  /// falle por unos segundos de diferencia entre el reloj del dispositivo y el del servidor.
  static const Duration margenRenovacion = Duration(minutes: 1);

  /// Tiempo máximo de espera de una petición.
  ///
  /// Es holgado a propósito: la primera petición del día puede coincidir con el arranque en
  /// frío de Lambda y con el despertar de la base de datos suspendida.
  static const Duration esperaConexion = Duration(seconds: 15);
  static const Duration esperaRespuesta = Duration(seconds: 30);
}
