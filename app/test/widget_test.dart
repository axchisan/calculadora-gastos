import 'package:calculadora_gastos/core/formato.dart';
import 'package:calculadora_gastos/dominio/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  group('Formato de dinero', () {
    test('usa punto como separador de miles y no muestra decimales', () {
      // El peso colombiano no se usa con centavos en el día a día.
      expect(Formato.dinero(3174000), r'$3.174.000');
      expect(Formato.dinero(0), r'$0');
    });

    test('los valores negativos conservan el signo', () {
      expect(Formato.dinero(-142000), contains('142.000'));
      expect(Formato.dinero(-142000), contains('-'));
    });

    test('marca explícitamente los aumentos', () {
      expect(Formato.dineroConSigno(50000), startsWith('+'));
      expect(Formato.dineroConSigno(-50000), isNot(startsWith('+')));
    });
  });

  group('Formato de fechas', () {
    test('escribe los meses en español con inicial mayúscula', () {
      expect(Formato.mesYAnio(DateTime(2026, 8)), 'Agosto 2026');
      expect(Formato.nombreDeMes(12), 'Diciembre');
    });

    test('escribe los días de la semana en español', () {
      // El 17 de agosto de 2026 es lunes: la Asunción trasladada.
      expect(Formato.diaDeLaSemana(DateTime(2026, 8, 17)), 'Lunes');
    });
  });

  group('Catálogos', () {
    test('traducen los códigos de la API a etiquetas legibles', () {
      expect(CategoriaGasto.desde('ALIMENTACION').etiqueta, 'Alimentación');
      expect(EstadoGasto.desde('PARCIAL').etiqueta, 'Abonado en parte');
      expect(TipoDia.desde('FIN_DE_SEMANA').etiqueta, 'Fin de semana');
    });

    test('un código desconocido no rompe la aplicación', () {
      // Si el servidor añadiera un valor nuevo, la app debe seguir funcionando.
      expect(CategoriaGasto.desde('CRIPTOMONEDAS'), CategoriaGasto.otro);
      expect(TipoDeuda.desde('HIPOTECA'), TipoDeuda.otro);
    });

    test(
      'solo se pueden asignar a mano los tipos de día que dependen del usuario',
      () {
        // Festivo y fin de semana los determina el calendario, no el usuario.
        expect(TipoDia.asignables, isNot(contains(TipoDia.festivo)));
        expect(TipoDia.asignables, isNot(contains(TipoDia.finDeSemana)));
        expect(TipoDia.asignables, contains(TipoDia.remoto));
      },
    );
  });

  group('Resumen mensual', () {
    final json = {
      'mesId': '019fc364-f3a4-7379-b66c-071e8945968d',
      'periodo': '2026-08',
      'cerrado': false,
      'ingresoBase': 3174000,
      'ingresosAdicionalesCobrados': 0,
      'ingresosAdicionalesTotales': 0,
      'ingresoTotal': 3174000,
      'ingresoProyectado': 3174000,
      'gastoTotal': 1132000,
      'gastoPagado': 600000,
      'gastoPendiente': 532000,
      'abonosDeuda': 0,
      'aporteAhorro': 0,
      'disponibleHoy': 2574000,
      'saldoProyectado': 2042000,
      'deudaTotal': 0,
      'ahorroTotal': 0,
      'patrimonioNeto': 0,
      'porCategoria': [
        {'categoria': 'VIVIENDA', 'total': 600000, 'porcentaje': 53.0},
      ],
    };

    test('interpreta el periodo "2026-08" como agosto de 2026', () {
      final resumen = ResumenMensual.deJson(json);
      expect(resumen.periodo.year, 2026);
      expect(resumen.periodo.month, 8);
    });

    test('distingue el disponible de hoy del saldo al cierre', () {
      final resumen = ResumenMensual.deJson(json);
      // Quedan $2.574.000 en la mano, pero el mes cerrará con $2.042.000 porque
      // aún faltan $532.000 por pagar.
      expect(resumen.disponibleHoy, 2574000);
      expect(resumen.saldoProyectado, 2042000);
      expect(
        resumen.disponibleHoy - resumen.saldoProyectado,
        resumen.gastoPendiente,
      );
    });

    test('reconoce cuándo el mes cierra en positivo', () {
      expect(ResumenMensual.deJson(json).cierraEnPositivo, isTrue);
      expect(
        ResumenMensual.deJson({
          ...json,
          'saldoProyectado': -50000,
        }).cierraEnPositivo,
        isFalse,
      );
    });
  });

  group('Gasto', () {
    Map<String, dynamic> gastoJson(Map<String, dynamic> extra) => {
      'id': 'g1',
      'nombre': 'Celular',
      'categoria': 'SERVICIOS',
      'monto': 100000,
      'montoPagado': 0,
      'saldoPendiente': 100000,
      'estado': 'PENDIENTE',
      'origen': 'PLANTILLA',
      'editable': true,
      ...extra,
    };

    test('calcula la proporción abonada', () {
      final gasto = Gasto.deJson(
        gastoJson({
          'montoPagado': 25000,
          'saldoPendiente': 75000,
          'estado': 'PARCIAL',
        }),
      );
      expect(gasto.proporcionPagada, 0.25);
    });

    test('un gasto sin importe cuenta como totalmente pagado', () {
      // Evita una división por cero al dibujar la barra de progreso.
      final gasto = Gasto.deJson(gastoJson({'monto': 0, 'saldoPendiente': 0}));
      expect(gasto.proporcionPagada, 1);
    });

    test('los gastos del sistema llegan marcados como no editables', () {
      final gasto = Gasto.deJson(
        gastoJson({'origen': 'TRANSPORTE', 'editable': false}),
      );
      expect(gasto.origen, OrigenGasto.transporte);
      expect(gasto.editable, isFalse);
    });
  });
}
