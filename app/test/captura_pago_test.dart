import 'package:calculadora_gastos/dominio/captura_pago.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reconocimiento de los pagos en las notificaciones del teléfono.
///
/// Los textos de este archivo son los reales, copiados de una compra hecha el 17 de agosto de
/// 2026 en SURTIMAYORISTA CLARET. No son ejemplos inventados: es exactamente lo que publica
/// cada aplicación, con sus rarezas —el importe en dos formatos distintos y el «with» en inglés
/// porque el sistema del teléfono está así.
void main() {
  NotificacionCapturada notificacion({
    required String paquete,
    required String titulo,
    required String texto,
    DateTime? instante,
  }) => NotificacionCapturada(
    id: 'n1',
    paquete: paquete,
    titulo: titulo,
    texto: texto,
    instante: instante ?? DateTime(2026, 8, 17, 15, 55),
  );

  group('Importes', () {
    test('los lee en el formato americano, que es el que usa la billetera', () {
      // El teléfono está en inglés, así que Google Wallet escribe COP54,670.00
      expect(LectorDePagos.interpretarMonto('54,670.00'), 54670);
      expect(LectorDePagos.interpretarMonto('2,500.00'), 2500);
      expect(LectorDePagos.interpretarMonto('1,234,567.00'), 1234567);
    });

    test('y en el colombiano, que es el que usa el banco', () {
      expect(LectorDePagos.interpretarMonto('54.670,00'), 54670);
      expect(LectorDePagos.interpretarMonto('2.500,00'), 2500);
      expect(LectorDePagos.interpretarMonto('1.234.567,00'), 1234567);
    });

    /// Es el punto donde una confusión cuesta dinero: dar por bueno el formato americano ante
    /// un importe colombiano convierte 54.670 pesos en 54,67.
    test('sin decimales, el separador es de miles en los dos formatos', () {
      expect(LectorDePagos.interpretarMonto('54.670'), 54670);
      expect(LectorDePagos.interpretarMonto('54,670'), 54670);
      expect(LectorDePagos.interpretarMonto('1.234.567'), 1234567);
    });

    test('con dos dígitos detrás, el separador es decimal', () {
      expect(LectorDePagos.interpretarMonto('54.67'), 54.67);
      expect(LectorDePagos.interpretarMonto('54,67'), 54.67);
    });

    test('ignora el símbolo de moneda venga como venga', () {
      expect(LectorDePagos.interpretarMonto(r'COP54,670.00'), 54670);
      expect(LectorDePagos.interpretarMonto(r'$54.670,00'), 54670);
      expect(LectorDePagos.interpretarMonto(r'COP $ 54.670,00'), 54670);
    });

    test('un texto sin cifras no devuelve nada', () {
      expect(LectorDePagos.interpretarMonto('aprobada'), isNull);
      expect(LectorDePagos.interpretarMonto(''), isNull);
    });
  });

  group('Notificación de Google Wallet', () {
    final real = notificacion(
      paquete: 'com.google.android.apps.walletnfcrel',
      titulo: 'SURTIMAYORISTA CLARET',
      texto: 'COP54,670.00 with crédito física',
    );

    test('saca el importe, el comercio y el apodo de la tarjeta', () {
      final pago = LectorDePagos.leer(real)!;

      expect(pago.monto, 54670);
      expect(pago.comercio, 'SURTIMAYORISTA CLARET');
      expect(pago.apodoTarjeta, 'crédito física');
      expect(pago.fuente, FuenteCaptura.wallet);
      // No trae los cuatro dígitos: eso solo lo publica el banco.
      expect(pago.ultimos4, isNull);
    });

    test('reconoce también las otras dos tarjetas de la billetera', () {
      for (final (apodo, importe) in [
        ('débito digital', 'COP2,500.00'),
        ('credito digital', 'COP99,000.00'),
      ]) {
        final pago = LectorDePagos.leer(
          notificacion(
            paquete: 'com.google.android.apps.walletnfcrel',
            titulo: 'BOLD SA*DELICIAS',
            texto: '$importe with $apodo',
          ),
        )!;
        expect(pago.apodoTarjeta, apodo);
      }
    });

    test('funcionaría igual con el teléfono en español', () {
      final pago = LectorDePagos.leer(
        notificacion(
          paquete: 'com.google.android.apps.walletnfcrel',
          titulo: 'SURTIMAYORISTA CLARET',
          texto: 'COP54.670,00 con crédito física',
        ),
      )!;

      expect(pago.monto, 54670);
      expect(pago.apodoTarjeta, 'crédito física');
    });

    test('una notificación que no es de pago se descarta', () {
      expect(
        LectorDePagos.leer(
          notificacion(
            paquete: 'com.google.android.apps.walletnfcrel',
            titulo: 'Tu pase está listo',
            texto: 'Añadiste una tarjeta de fidelización',
          ),
        ),
        isNull,
      );
    });
  });

  group('Notificación de Nu', () {
    final real = notificacion(
      paquete: 'com.nu.production',
      titulo: r'Compra aprobada por $54.670,00',
      texto:
          r'Tu compra en SURTIMAYORISTA CLARET por $54.670,00 con tu tarjeta '
          'terminada en 2355 ha sido APROBADA.',
    );

    test('saca el importe, el comercio y los cuatro últimos dígitos', () {
      final pago = LectorDePagos.leer(real)!;

      expect(pago.monto, 54670);
      expect(pago.comercio, 'SURTIMAYORISTA CLARET');
      expect(pago.ultimos4, '2355');
      expect(pago.fuente, FuenteCaptura.banco);
    });

    /// Una compra rechazada no movió dinero. Capturarla llenaría la bandeja de cosas que hay
    /// que descartar a mano, que es justo lo que hace que se deje de usar.
    test('las compras rechazadas no se capturan', () {
      expect(
        LectorDePagos.leer(
          notificacion(
            paquete: 'com.nu.production',
            titulo: r'Compra rechazada por $9.000,00',
            texto:
                r'Tu compra en SUPERTIENDA OLIMPICA por $9.000,00 con tu tarjeta '
                'terminada en 2355 fue RECHAZADA.',
          ),
        ),
        isNull,
      );
    });

    test('un aviso que no es una compra tampoco', () {
      expect(
        LectorDePagos.leer(
          notificacion(
            paquete: 'com.nu.production',
            titulo: 'Tu extracto está listo',
            texto: 'Ya puedes consultar el extracto de este mes.',
          ),
        ),
        isNull,
      );
    });
  });

  group('La misma compra vista dos veces', () {
    final deWallet = LectorDePagos.leer(
      notificacion(
        paquete: 'com.google.android.apps.walletnfcrel',
        titulo: 'SURTIMAYORISTA CLARET',
        texto: 'COP54,670.00 with crédito física',
        instante: DateTime(2026, 8, 17, 15, 55, 10),
      ),
    )!;

    final delBanco = LectorDePagos.leer(
      notificacion(
        paquete: 'com.nu.production',
        titulo: r'Compra aprobada por $54.670,00',
        texto:
            r'Tu compra en SURTIMAYORISTA CLARET por $54.670,00 con tu tarjeta '
            'terminada en 2355 ha sido APROBADA.',
        instante: DateTime(2026, 8, 17, 15, 55, 22),
      ),
    )!;

    test('se reconocen como una sola', () {
      // Al pagar llegan las dos casi a la vez. Sin esto, cada compra entraría por duplicado.
      expect(deWallet.esLaMismaCompraQue(delBanco), isTrue);
    });

    test('al juntarlas se conserva lo que aporta cada una', () {
      final pago = deWallet.fusionarCon(delBanco);

      expect(pago.monto, 54670);
      expect(pago.comercio, 'SURTIMAYORISTA CLARET');
      // El apodo lo trae la billetera...
      expect(pago.apodoTarjeta, 'crédito física');
      // ...y los dígitos, el banco.
      expect(pago.ultimos4, '2355');
      // Se queda el instante más temprano, que es el de la compra.
      expect(pago.instante, DateTime(2026, 8, 17, 15, 55, 10));
    });

    test('dos compras del mismo importe en días distintos no se confunden', () {
      final otroDia = LectorDePagos.leer(
        notificacion(
          paquete: 'com.google.android.apps.walletnfcrel',
          titulo: 'SURTIMAYORISTA CLARET',
          texto: 'COP54,670.00 with crédito física',
          instante: DateTime(2026, 8, 18, 15, 55, 10),
        ),
      )!;

      expect(deWallet.esLaMismaCompraQue(otroDia), isFalse);
    });

    test('dos importes distintos a la vez son dos compras', () {
      final otra = LectorDePagos.leer(
        notificacion(
          paquete: 'com.google.android.apps.walletnfcrel',
          titulo: 'OTRO COMERCIO',
          texto: 'COP2,500.00 with débito digital',
          instante: DateTime(2026, 8, 17, 15, 55, 30),
        ),
      )!;

      expect(deWallet.esLaMismaCompraQue(otra), isFalse);
    });
  });

  test('una notificación de otra aplicación se ignora', () {
    expect(
      LectorDePagos.leer(
        notificacion(
          paquete: 'com.whatsapp',
          titulo: 'Mamá',
          texto: r'Te mandé $54.670,00',
        ),
      ),
      isNull,
    );
  });
}
