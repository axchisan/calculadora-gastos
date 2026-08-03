import 'package:calculadora_gastos/datos/almacen_sesion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Comprueba el almacén seguro contra el sistema real.
///
/// No puede verificarse con una prueba normal: depende del Keychain en macOS y del Keystore en
/// Android, que solo existen en el dispositivo. En macOS falla con el código -34018 si el
/// paquete usa el «data protection keychain» sin el entitlement correspondiente, y el síntoma
/// es que iniciar sesión no hace nada.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final almacen = AlmacenSesion();

  final sesion = SesionGuardada(
    accessToken: 'token-de-prueba',
    refreshToken: 'refresco-de-prueba',
    expiraEn: DateTime.now().add(const Duration(minutes: 15)),
    usuarioId: '019fc364-f3a4-7379-b66c-071e8945968d',
    email: 'prueba@axchisan.com',
    nombre: 'Duvan',
  );

  tearDown(() async => almacen.borrar());

  testWidgets('guarda la sesión y la recupera', (tester) async {
    await almacen.guardar(sesion);
    final leida = await almacen.leer();

    expect(leida, isNotNull);
    expect(leida!.accessToken, sesion.accessToken);
    expect(leida.refreshToken, sesion.refreshToken);
    expect(leida.email, sesion.email);
  });

  testWidgets('sin sesión guardada devuelve nulo', (tester) async {
    await almacen.borrar();
    expect(await almacen.leer(), isNull);
  });

  testWidgets('borrar deja el almacén vacío', (tester) async {
    await almacen.guardar(sesion);
    expect(await almacen.leer(), isNotNull);

    await almacen.borrar();
    expect(await almacen.leer(), isNull);
  });

  testWidgets('conserva el instante de caducidad', (tester) async {
    await almacen.guardar(sesion);
    final leida = await almacen.leer();

    // Sin esto, la aplicación no sabría cuándo renovar el token.
    expect(
      leida!.expiraEn.difference(sesion.expiraEn).inSeconds.abs(),
      lessThan(2),
    );
    expect(leida.estaVigente, isTrue);
  });
}
