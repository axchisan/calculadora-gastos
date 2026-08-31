import 'package:calculadora_gastos/core/dinero.dart';
import 'package:calculadora_gastos/core/formato.dart';
import 'package:calculadora_gastos/core/version.dart';
import 'package:calculadora_gastos/dominio/modelos.dart';
import 'package:calculadora_gastos/estado/modo_vista.dart';
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
      'comprometido': 1132000,
      'porcentajeComprometido': 35.66,
      'cuotasDeudaPendientes': 0,
      'comprometidoConCuotas': 1132000,
      'deudasSinCuota': 0,
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

    test('separa lo comprometido de lo ya pagado', () {
      final resumen = ResumenMensual.deJson(json);
      // En un mes por empezar, lo pagado es cero y no dice nada; lo comprometido sí.
      expect(resumen.comprometido, 1132000);
      expect(resumen.porcentajeComprometido, 35.66);
      expect(resumen.comprometido, greaterThan(resumen.gastoPagado));
    });

    test('avisa cuando se ha comprometido más de lo que se ingresa', () {
      expect(ResumenMensual.deJson(json).estaSobrecomprometido, isFalse);
      expect(
        ResumenMensual.deJson({
          ...json,
          'comprometidoConCuotas': 4000000,
        }).estaSobrecomprometido,
        isTrue,
      );
    });

    test('las cuotas de deuda ocupan cupo aunque no se hayan pagado', () {
      // Una deuda con cuota pactada seguirá pidiendo dinero este mes.
      final resumen = ResumenMensual.deJson({
        ...json,
        'cuotasDeudaPendientes': 200000,
        'comprometidoConCuotas': 1332000,
      });

      expect(resumen.cuotasDeudaPendientes, 200000);
      // 3.174.000 menos 1.332.000
      expect(resumen.saldoTrasCuotas, 1842000);
      // El saldo proyectado, que no cuenta las cuotas, queda por encima.
      expect(resumen.saldoTrasCuotas, lessThan(resumen.saldoProyectado));
    });

    test('suma todo el dinero que ya salió del mes', () {
      // La barra de pagos solo cuenta gastos; un abono a una deuda también sale del bolsillo.
      final resumen = ResumenMensual.deJson({
        ...json,
        'gastoPagado': 600000,
        'abonosDeuda': 2000,
        'aporteAhorro': 50000,
      });

      expect(resumen.salidaReal, 652000);
    });

    test('las compras del día a día también salieron del bolsillo', () {
      final resumen = ResumenMensual.deJson({
        ...json,
        'gastoPagado': 600000,
        'comprasInmediatas': 14300,
        'cortesTarjetaPagados': 100000,
      });

      expect(resumen.salidaReal, 714300);
    });

    test('lo cargado a crédito no cuenta como salida de este mes', () {
      // Se compró en agosto pero el dinero se va cuando venza el corte.
      final resumen = ResumenMensual.deJson({
        ...json,
        'gastoPagado': 600000,
        'comprasDelMes': 100000,
        'comprasInmediatas': 0,
        'comprasACredito': 100000,
      });

      expect(resumen.salidaReal, 600000);
      expect(resumen.tieneCreditoPorVencer, isTrue);
    });

    test('un resumen guardado antes de las compras se sigue leyendo', () {
      // El caché sin conexión puede tener respuestas de una versión anterior de la API.
      final resumen = ResumenMensual.deJson(json);
      expect(resumen.comprasDelMes, 0);
      expect(resumen.cortesTarjetaPendientes, 0);
      expect(resumen.tieneCreditoPorVencer, isFalse);
    });

    test('lo que falta cuenta también las cuotas de deuda', () {
      // Una cuota de deuda hay que pagarla igual que el arriendo.
      final resumen = ResumenMensual.deJson({
        ...json,
        'gastoTotal': 1232000,
        'gastoPagado': 0,
        'cuotasDeudaPendientes': 1711000,
        'comprometidoConCuotas': 2943000,
      });

      expect(resumen.salidaReal, 0);
      expect(resumen.pendienteTotal, 2943000);
      expect(resumen.proporcionCubierta, 0);
    });

    test('abonar una deuda cuenta como pagado', () {
      final resumen = ResumenMensual.deJson({
        ...json,
        'gastoPagado': 600000,
        'abonosDeuda': 400000,
        'cuotasDeudaPendientes': 100000,
        'comprometidoConCuotas': 1632000,
      });

      // 600.000 de gastos más 400.000 abonados a deudas
      expect(resumen.salidaReal, 1000000);
      expect(resumen.pendienteTotal, 632000);
      expect(resumen.proporcionCubierta, closeTo(0.6127, 0.001));
    });

    test('pagar de más no deja un pendiente negativo', () {
      final resumen = ResumenMensual.deJson({
        ...json,
        'gastoPagado': 1132000,
        'abonosDeuda': 900000,
        'comprometidoConCuotas': 1500000,
      });

      expect(resumen.pendienteTotal, 0);
      expect(resumen.proporcionCubierta, 1.0);
    });

    test('sin nada comprometido la barra no se divide por cero', () {
      final resumen = ResumenMensual.deJson({
        ...json,
        'gastoTotal': 0,
        'gastoPagado': 0,
        'comprometidoConCuotas': 0,
      });

      expect(resumen.proporcionCubierta, 0);
      expect(resumen.pendienteTotal, 0);
    });

    test('cuenta las deudas que no pueden proyectarse', () {
      expect(ResumenMensual.deJson(json).deudasSinCuota, 0);
      expect(
        ResumenMensual.deJson({...json, 'deudasSinCuota': 4}).deudasSinCuota,
        4,
      );
    });

    test('la proporción comprometida nunca se sale de la barra', () {
      // Con más compromisos que ingreso, la barra se queda llena en vez de desbordarse.
      expect(
        ResumenMensual.deJson({
          ...json,
          'comprometidoConCuotas': 9000000,
        }).proporcionComprometida,
        1.0,
      );

      // Y sin ingreso registrado no se divide por cero.
      expect(
        ResumenMensual.deJson({
          ...json,
          'ingresoProyectado': 0,
          'comprometidoConCuotas': 100000,
        }).proporcionComprometida,
        0,
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

  group('Importes con centavos', () {
    test('las cifras redondas se muestran sin decimales', () {
      // El peso se maneja en cifras redondas y arrastrar «,00» detrás de cada importe
      // emborrona la lectura de una lista entera.
      expect(Formato.dinero(11500), r'$11.500');
      expect(Formato.dinero(3174000), r'$3.174.000');
    });

    test('y con decimales cuando los tienen', () {
      // Un plan de pagos sí los trae, y redondearlos descuadraría contra el papel del banco.
      expect(Formato.dinero(192729.03), r'$192.729,03');
      expect(Formato.dinero(404304.50), r'$404.304,50');
    });

    test('reconoce cuándo hay centavos de verdad', () {
      expect(Formato.tieneCentavos(192729.03), isTrue);
      // En coma flotante 11500.0 puede no ser exacto; la comprobación va sobre céntimos.
      expect(Formato.tieneCentavos(11500), isFalse);
      expect(Formato.tieneCentavos(0.1 + 0.2), isTrue);
    });

    test(
      'el formato exacto siempre los enseña, para columnas que deben cuadrar',
      () {
        expect(Formato.dineroExacto(11500), r'$11.500,00');
      },
    );
  });

  group('Interpretar lo que se teclea', () {
    test('acepta el formato colombiano', () {
      expect(Dinero.interpretar('192.729,03'), 192729.03);
      expect(Dinero.interpretar('11.500'), 11500);
    });

    test('y el que sale de un teclado con punto', () {
      expect(Dinero.interpretar('192729.03'), 192729.03);
      expect(Dinero.interpretar('11500'), 11500);
    });

    test('lo que se escribe en el campo vuelve igual', () {
      // Editar una compra no debe cambiarle el importe por el camino.
      for (final valor in [11500.0, 192729.03, 0.5, 404304.50]) {
        expect(Dinero.interpretar(Dinero.paraEditar(valor)), valor);
      }
    });

    test('el campo se abre ya con los separadores puestos', () {
      // Si el campo se abriera con «192729» y pasara a «192.729» al tocar una tecla,
      // desconcertaría. Se abre como quedaría al teclearlo.
      expect(Dinero.paraEditar(11500), '11.500');
      expect(Dinero.paraEditar(192729.03), '192.729,03');
      expect(Dinero.paraEditar(500), '500');
    });

    test('los separadores se ponen cada tres cifras desde la derecha', () {
      expect(FormatoDeImporte.conSeparadores('192729'), '192.729');
      expect(FormatoDeImporte.conSeparadores('1234567'), '1.234.567');
      expect(FormatoDeImporte.conSeparadores('500'), '500');
      expect(FormatoDeImporte.conSeparadores('1000'), '1.000');
    });
  });

  group('Compras del día a día', () {
    Map<String, dynamic> compraJson(Map<String, dynamic> extra) => {
      'id': 'c1',
      'fecha': '2026-08-14',
      'descripcion': 'Chocorramo',
      'categoria': 'ANTOJOS',
      'monto': 3600,
      'medio': 'EFECTIVO',
      'periodoPago': '2026-08',
      'vencimiento': '2026-08-14',
      'pagado': true,
      'origen': 'MANUAL',
      ...extra,
    };

    test('lo pagado en efectivo sale el mismo día', () {
      final compra = Compra.deJson(compraJson({}));
      expect(compra.medio.saleAlInstante, isTrue);
      expect(compra.periodoPago, DateTime(2026, 8));
      expect(compra.quedaPorPagar, isFalse);
    });

    test('lo pagado a crédito sale otro mes y queda pendiente', () {
      final compra = Compra.deJson(
        compraJson({
          'medio': 'CREDITO',
          'periodoPago': '2026-09',
          'vencimiento': '2026-09-04',
          'pagado': false,
          'tarjetaNombre': 'Nu',
        }),
      );

      expect(compra.periodoPago, DateTime(2026, 9));
      expect(compra.vencimiento, DateTime(2026, 9, 4));
      expect(compra.quedaPorPagar, isTrue);
    });

    test('la media por día solo cuenta los días en que hubo compras', () {
      final datos = ComprasDelMes.deJson({
        'total': 14300,
        'inmediato': 14300,
        'aCredito': 0,
        'porDia': [
          {'fecha': '2026-08-05', 'total': 5800},
          {'fecha': '2026-08-09', 'total': 8500},
        ],
        'compras': [compraJson({})],
      });

      // 14.300 en dos días con gasto, no repartidos entre los 31 del mes.
      expect(datos.promedioPorDia, 7150);
      expect(datos.diaMasCaro?.fecha, DateTime(2026, 8, 9));
    });

    test('un mes sin compras no divide por cero', () {
      expect(ComprasDelMes.vacio.promedioPorDia, 0);
      expect(ComprasDelMes.vacio.diaMasCaro, isNull);
    });

    test('las categorías de compra dejan fuera las de compromiso mensual', () {
      // Nadie compra «vivienda» sobre la marcha; verla al elegir deprisa solo estorba.
      expect(
        CategoriaGasto.deCompras,
        isNot(contains(CategoriaGasto.vivienda)),
      );
      expect(
        CategoriaGasto.deCompras,
        isNot(contains(CategoriaGasto.suscripciones)),
      );
      expect(CategoriaGasto.deCompras, contains(CategoriaGasto.antojos));
    });
  });

  group('Ciclo de la tarjeta', () {
    // Corte el 15, pago el 4 del mes siguiente.
    const nu = Tarjeta(
      id: 't1',
      nombre: 'Nu',
      tipo: TipoTarjeta.credito,
      activa: true,
      diaCorte: 15,
      diaPago: 4,
    );

    test('antes del corte se paga el mes siguiente', () {
      expect(nu.vencimientoDe(DateTime(2026, 8, 14)), DateTime(2026, 9, 4));
      // El propio día del corte todavía entra.
      expect(nu.vencimientoDe(DateTime(2026, 8, 15)), DateTime(2026, 9, 4));
    });

    test('pasado el corte se va un mes más allá', () {
      expect(nu.vencimientoDe(DateTime(2026, 8, 16)), DateTime(2026, 10, 4));
    });

    test('el cambio de año no lo despista', () {
      expect(nu.vencimientoDe(DateTime(2026, 12, 20)), DateTime(2027, 2, 4));
    });

    test('una tarjeta de débito no tiene ciclo', () {
      const debito = Tarjeta(
        id: 't2',
        nombre: 'Débito',
        tipo: TipoTarjeta.debito,
        activa: true,
      );
      expect(debito.vencimientoDe(DateTime(2026, 8, 14)), isNull);
      expect(debito.resumenCiclo, isNull);
    });
  });

  group('Reconocer la tarjeta de una notificación', () {
    // Los apodos son los reales de la billetera, con su inconsistencia incluida: uno lleva
    // tilde y el otro no, aunque los escribió la misma persona.
    const nu = Tarjeta(
      id: 't1',
      nombre: 'Nu',
      tipo: TipoTarjeta.credito,
      activa: true,
      diaCorte: 15,
      diaPago: 4,
      alias: [
        AliasTarjeta(id: 'a1', apodo: 'crédito física', ultimos4: '2355'),
        AliasTarjeta(id: 'a2', apodo: 'credito digital', ultimos4: '1086'),
      ],
    );

    const bancolombia = Tarjeta(
      id: 't2',
      nombre: 'Bancolombia',
      tipo: TipoTarjeta.debito,
      activa: true,
      alias: [
        AliasTarjeta(id: 'a3', apodo: 'débito digital', ultimos4: '8329'),
      ],
    );

    test('la reconoce por los cuatro últimos dígitos', () {
      expect(nu.reconoce(ultimos4: '2355'), isTrue);
      expect(nu.reconoce(ultimos4: '8329'), isFalse);
      expect(bancolombia.reconoce(ultimos4: '8329'), isTrue);
    });

    test('y por el apodo que tiene en la billetera', () {
      expect(nu.reconoce(apodo: 'crédito física'), isTrue);
      expect(nu.reconoce(apodo: 'credito digital'), isTrue);
      expect(bancolombia.reconoce(apodo: 'débito digital'), isTrue);
    });

    /// Es el detalle que rompería el reconocimiento la mitad de las veces: los apodos se
    /// escriben a mano y las tildes van y vienen.
    test('las tildes y las mayúsculas no le importan', () {
      expect(nu.reconoce(apodo: 'credito fisica'), isTrue);
      expect(nu.reconoce(apodo: 'CRÉDITO FÍSICA'), isTrue);
      expect(nu.reconoce(apodo: '  crédito física  '), isTrue);
      expect(bancolombia.reconoce(apodo: 'debito digital'), isTrue);
    });

    test('una tarjeta que no es la suya no responde', () {
      expect(nu.reconoce(apodo: 'débito digital'), isFalse);
      expect(bancolombia.reconoce(apodo: 'crédito física'), isFalse);
    });

    test('sin alias configurados no reconoce nada', () {
      const sinAlias = Tarjeta(
        id: 't3',
        nombre: 'Otra',
        tipo: TipoTarjeta.debito,
        activa: true,
      );
      expect(sinAlias.reconoce(apodo: 'lo que sea', ultimos4: '0000'), isFalse);
    });
  });

  group('Modo de vista', () {
    test('alterna entre lo pagado y lo comprometido', () {
      expect(ModoVista.real.contrario, ModoVista.estimacion);
      expect(ModoVista.estimacion.contrario, ModoVista.real);
    });

    test('cada modo explica qué mide', () {
      expect(ModoVista.real.descripcion, contains('pagado'));
      expect(ModoVista.estimacion.descripcion, contains('comprometido'));
    });
  });

  group('Versión de la aplicación', () {
    test('junta la versión y el número de compilación', () {
      const v = VersionApp(
        nombre: 'Mis gastos',
        version: '1.6.1',
        compilacion: '11',
      );
      expect(v.etiqueta, '1.6.1 (11)');
    });

    test('sin número de compilación muestra solo la versión', () {
      // La web no tiene número de compilación y ahí sobra el paréntesis vacío.
      const v = VersionApp(
        nombre: 'Mis gastos',
        version: '1.6.1',
        compilacion: '',
      );
      expect(v.etiqueta, '1.6.1');
    });
  });
}
