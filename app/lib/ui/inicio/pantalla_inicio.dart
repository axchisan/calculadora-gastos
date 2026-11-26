import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/cuentas_y_sueldo.dart';
import '../../dominio/inicio.dart';
import '../../dominio/modelos.dart';
import '../../estado/autenticacion.dart';
import '../../estado/inicio.dart';
import '../../estado/mes.dart';
import '../../estado/modulos.dart';
import '../../estado/plan.dart';
import '../../estado/proveedores.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';
import '../apuntar/hoja_apuntar.dart';
import '../plan/ilustracion_meta.dart';

/// Inicio: cuánto tienes, qué tienes que pagar pronto y cómo va el mes, sin hacer cuentas.
///
/// Todo sale de una sola lectura (`GET /api/inicio`), que se enseña al instante desde la copia
/// local y se actualiza por detrás.
class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(inicioProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: datos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Error(
            mensaje: error is ErrorApi
                ? error.mensaje
                : 'No se pudo cargar el inicio',
            alReintentar: () => ref.invalidate(inicioProvider),
          ),
          data: (d) => _Contenido(datos: d),
        ),
      ),
      floatingActionButton: datos.hasValue
          ? FloatingActionButton(
              tooltip: 'Apuntar',
              onPressed: () => _apuntar(context, ref, datos.requireValue),
              child: const Icon(Iconos.anadir),
            )
          : null,
    );
  }

  /// Un solo botón para apuntar cualquier cosa. Va al mes en curso, no al que se esté viendo
  /// en Movimientos: lo que se apunta desde Inicio es de hoy.
  Future<void> _apuntar(
    BuildContext context,
    WidgetRef ref,
    DatosInicio datos,
  ) async {
    final mesId = datos.resumen?.mesId;
    if (mesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abre el mes en Movimientos antes de apuntar en él'),
        ),
      );
      return;
    }
    await HojaApuntar.abrir(context, mesId: mesId, periodo: datos.periodo);
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.datos});

  final DatosInicio datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulos = ref.watch(modulosProvider);
    final ancho = Pantalla.esEscritorio(context) ? 640.0 : double.infinity;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(clienteApiProvider).revisarTodo();
        await ref.refresh(inicioProvider.future).catchError((_) => datos);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lateral,
              Espacio.m,
              Espacio.lateral,
              96,
            ),
            children: [
              _Cabecera(datos: datos),
              const SizedBox(height: Espacio.xl),
              _Cifra(datos: datos),
              ..._aviso(context),
              _ProximosPagos(datos: datos),
              const _MiPlan(),
              _EsteMes(datos: datos),
              if (datos.tieneCuentas) _MisCuentas(cuentas: datos.cuentas),
              if (datos.proximoSueldo != null)
                _TuSueldo(pago: datos.proximoSueldo!),
              if (modulos.isNotEmpty) _Modulos(modulos: modulos),
            ],
          ),
        ),
      ),
    );
  }

  /// Una frase con lo que antes había que deducir de varias cifras.
  List<Widget> _aviso(BuildContext context) {
    final negrita = TextStyle(
      fontWeight: FontWeight.w700,
      color: context.colores.tinta,
    );
    final vencidos = datos.vencidos;
    if (vencidos.isNotEmpty) {
      final total = vencidos.fold<double>(0, (s, p) => s + p.monto);
      return [
        const SizedBox(height: Espacio.xl),
        CajaAviso(
          tono: Tono.negativo,
          icono: Iconos.atencion,
          texto: TextSpan(
            children: [
              TextSpan(
                text: vencidos.length == 1
                    ? 'Se pasó la fecha de '
                    : 'Se pasó la fecha de ${vencidos.length} pagos: ',
              ),
              TextSpan(
                text:
                    '${_lista(vencidos.map((p) => p.titulo))} '
                    '(${Formato.pesos(total)})',
                style: negrita,
              ),
              const TextSpan(text: '. Si ya lo pagaste, márcalo como pagado.'),
            ],
          ),
        ),
      ];
    }

    final pendientes = datos.pendientesDelMes;
    if (pendientes.isEmpty) return const [];
    final total = pendientes.fold<double>(0, (s, p) => s + p.monto);
    final queda = datos.quedaHastaElSueldo;
    final hasta = datos.proximoSueldo != null
        ? 'hasta que llegue tu sueldo'
        : 'hasta cerrar el mes';

    return [
      const SizedBox(height: Espacio.xl),
      CajaAviso(
        icono: Iconos.atencion,
        tono: queda < 0 ? Tono.aviso : Tono.suave,
        texto: TextSpan(
          children: [
            const TextSpan(text: 'Te falta pagar '),
            TextSpan(
              text: pendientes.length == 1
                  ? '«${_corto(pendientes.first.titulo)}» '
                        '(${Formato.pesos(total)})'
                  : '${pendientes.length} gastos del mes '
                        '(${Formato.pesos(total)})',
              style: negrita,
            ),
            TextSpan(
              text: queda < 0
                  ? '. Con lo que tienes, te faltarían '
                  : '. Después de pagar lo que vence te quedan ',
            ),
            TextSpan(text: Formato.pesos(queda.abs()), style: negrita),
            TextSpan(text: ' $hasta.'),
          ],
        ),
      ),
    ];
  }
}

class _Cabecera extends ConsumerWidget {
  const _Cabecera({required this.datos});

  final DatosInicio datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final sesion = ref.watch(sesionProvider);
    final nombre = sesion is SesionAbierta ? sesion.sesion.nombre.trim() : '';
    final pila = nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final iniciales = pila.take(2).map((p) => p[0].toUpperCase()).join();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pila.isEmpty ? 'Hola' : 'Hola, ${pila.first}',
                style: textos.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '${Formato.nombreDeMes(datos.periodo.month)} · '
                '${_diaYMes(datos.inicioDelMes)} – ${_diaYMes(datos.finDelMes)}',
                style: textos.bodyMedium?.copyWith(color: c.tinta2),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Ajustes',
          child: Material(
            color: c.superficie2,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(Rutas.ajustes),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: iniciales.isEmpty
                      ? Icon(Iconos.ajustes, color: c.tinta2)
                      : Text(
                          iniciales,
                          style: Tipo.estilo(15, 700, color: c.tinta),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.datos});

  final DatosInicio datos;

  @override
  Widget build(BuildContext context) {
    final diferencia = datos.diferenciaConLaApp;
    final dias = datos.diasParaCerrar;

    return CifraPrincipal(
      etiqueta: datos.tieneCuentas ? 'Tienes hoy' : 'Disponible hoy',
      valor: datos.tienesHoy,
      debajo: [
        if (diferencia != null)
          datos.cuadra
              ? Etiqueta(
                  'Cuadra con tus bancos',
                  tono: Tono.positivo,
                  icono: Iconos.listo,
                  grande: true,
                  alTocar: () => context.push(Rutas.cuentas),
                )
              : Etiqueta(
                  diferencia > 0
                      ? 'Tienes ${Formato.pesos(diferencia)} más que la app'
                      : 'Te faltan ${Formato.pesos(-diferencia)} frente a la app',
                  tono: Tono.aviso,
                  icono: Iconos.atencion,
                  grande: true,
                  alTocar: () => context.push(Rutas.cuentas),
                )
        else if (!datos.tieneCuentas)
          Etiqueta(
            'Anota tus cuentas para cuadrar',
            icono: Iconos.banco,
            grande: true,
            alTocar: () => context.push(Rutas.cuentas),
          ),
        if (dias >= 0)
          Etiqueta(
            dias == 0
                ? 'Hoy cierra el mes'
                : dias == 1
                ? 'Mañana cierra el mes'
                : 'Faltan $dias días para cerrar el mes',
            icono: Iconos.calendario,
            grande: true,
          ),
      ],
    );
  }
}

class _ProximosPagos extends ConsumerWidget {
  const _ProximosPagos({required this.datos});

  final DatosInicio datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagos = datos.proximosPagos;
    final juntos = datos.pagosJuntos;
    final textos = Theme.of(context).textTheme;
    final c = context.colores;

    if (pagos.isEmpty) {
      return Seccion(
        titulo: 'Próximos pagos',
        accion: '30 días',
        child: Panel(
          child: Text(
            'Nada por pagar en los próximos 30 días.',
            style: textos.bodyMedium?.copyWith(color: c.tinta2),
          ),
        ),
      );
    }

    final notas = <String>[
      for (final dia in juntos.entries.take(1))
        'El ${_diaYMes(dia.key)} pagas '
            '${Formato.pesos(dia.value.fold<double>(0, (s, p) => s + p.monto))} '
            'entre ${_lista(dia.value.map((p) => _corto(p.titulo)))}.',
      if (datos.proximoSueldo case final sueldo?)
        if (sueldo.fecha != null)
          sueldo.fechaHasta == null || sueldo.fechaHasta == sueldo.fecha
              ? 'Tu sueldo llega el ${_diaYMes(sueldo.fecha!)}.'
              : 'Tu sueldo llega entre el ${sueldo.fecha!.day} y el '
                    '${_diaYMes(sueldo.fechaHasta!)}.',
    ];

    return Seccion(
      titulo: 'Próximos pagos',
      accion: '30 días',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Panel.lista(
            filas: [
              for (final p in pagos)
                _FilaPago(
                  pago: p,
                  mesDelPeriodo: datos.periodo,
                  mismoDia:
                      p.fecha != null &&
                      juntos.containsKey(
                        DateTime(p.fecha!.year, p.fecha!.month, p.fecha!.day),
                      ),
                ),
            ],
          ),
          if (notas.isNotEmpty) ...[
            const SizedBox(height: Espacio.m),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                notas.join(' '),
                style: textos.bodySmall?.copyWith(color: c.tinta2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaPago extends ConsumerWidget {
  const _FilaPago({
    required this.pago,
    required this.mesDelPeriodo,
    required this.mismoDia,
  });

  final ProximoPago pago;
  final DateTime mesDelPeriodo;
  final bool mismoDia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fecha = pago.fecha;
    final hasta = pago.fechaHasta;
    final dia = fecha == null
        ? '—'
        : hasta != null && hasta != fecha && hasta.month == fecha.month
        ? '${fecha.day}–${hasta.day}'
        : '${fecha.day}';
    final mes = _mesCorto((fecha ?? mesDelPeriodo).month);

    return Fila(
      inicio: FechaCorta(dia: dia, mes: mes),
      titulo: pago.titulo,
      subtitulo: pago.detalle.isEmpty ? null : pago.detalle,
      etiqueta: pago.vencido
          ? const Etiqueta('Vencido', tono: Tono.negativo)
          : mismoDia
          ? const Etiqueta('Mismo día', tono: Tono.aviso)
          : null,
      importe: pago.monto,
      importeConSigno: pago.ingreso,
      debajoDelImporte: pago.ingreso ? 'estimado' : null,
      alTocar: () => _abrir(context, ref),
    );
  }

  void _abrir(BuildContext context, WidgetRef ref) {
    switch (pago.tipo) {
      case TipoProximoPago.gasto:
        // El gasto puede ser del mes siguiente: se abre el mes al que pertenece.
        final f = pago.fecha;
        ref.read(periodoProvider.notifier).state = f == null
            ? mesDelPeriodo
            : DateTime(f.year, f.month + (f.day >= 28 ? 1 : 0));
        context.go(Rutas.movimientos);
      case TipoProximoPago.cuotaCredito || TipoProximoPago.deuda:
        context.go(Rutas.deudas);
      case TipoProximoPago.sueldo:
        context.push(Rutas.sueldo);
    }
  }
}

class _EsteMes extends StatelessWidget {
  const _EsteMes({required this.datos});

  final DatosInicio datos;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final r = datos.resumen;

    void verMovimientos() => context.go(Rutas.movimientos);

    if (r == null) {
      return Seccion(
        titulo: 'Este mes',
        child: Panel(
          child: Text(
            '${Formato.nombreDeMes(datos.periodo.month)} aún no está creado. '
            'Ábrelo en Movimientos para empezar.',
            style: textos.bodyMedium?.copyWith(color: c.tinta2),
          ),
        ),
      );
    }

    final entro = r.ingresoTotal;
    final salio = entro - r.disponibleHoy;
    final proporcion = entro <= 0 ? 0.0 : (salio / entro).clamp(0.0, 1.0);

    Widget cifra(IconData icono, String etiqueta, double valor) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 16, color: c.tinta2),
            const SizedBox(width: 6),
            Text(etiqueta, style: textos.bodyMedium?.copyWith(color: c.tinta2)),
          ],
        ),
        const SizedBox(height: Espacio.xs),
        Text(Formato.pesos(valor), style: textos.titleLarge),
      ],
    );

    return Seccion(
      titulo: 'Este mes',
      accion: 'Ver movimientos',
      alTocarAccion: verMovimientos,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: cifra(Iconos.entro, 'Entró', entro)),
                Expanded(child: cifra(Iconos.salio, 'Salió', salio)),
              ],
            ),
            if (entro > 0) ...[
              const SizedBox(height: Espacio.l),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: proporcion,
                  minHeight: 8,
                  backgroundColor: c.superficie2,
                  color: salio > entro ? c.negativo : c.tinta,
                ),
              ),
              const SizedBox(height: Espacio.m),
              Text(
                salio > entro
                    ? 'Salió más de lo que entró este mes.'
                    : 'Gastaste el ${(salio / entro * 100).round()} % de lo '
                          'que entró.',
                style: textos.bodySmall?.copyWith(color: c.tinta2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MisCuentas extends StatelessWidget {
  const _MisCuentas({required this.cuentas});

  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final activas = cuentas.where((x) => x.activa).toList();

    return Seccion(
      titulo: 'Mis cuentas',
      accion: 'Actualizar',
      alTocarAccion: () => context.push(Rutas.cuentas),
      child: LayoutBuilder(
        builder: (context, limites) {
          final columnas = limites.maxWidth > 480 ? 3 : 2;
          final ancho =
              (limites.maxWidth - Espacio.m * (columnas - 1)) / columnas;
          return Wrap(
            spacing: Espacio.m,
            runSpacing: Espacio.m,
            children: [
              for (final cuenta in activas)
                SizedBox(
                  width: ancho,
                  child: Panel(
                    relleno: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => context.push(Rutas.cuentas),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _iconoCuenta(cuenta.tipo),
                                  size: 16,
                                  color: c.tinta2,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    cuenta.nombre,
                                    style: textos.bodySmall?.copyWith(
                                      color: c.tinta2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Espacio.s),
                            Text(
                              cuenta.saldo > 0 && cuenta.saldo < 1
                                  ? Formato.dinero(cuenta.saldo)
                                  : Formato.pesos(cuenta.saldo),
                              style: textos.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static IconData _iconoCuenta(TipoCuenta tipo) => switch (tipo) {
    TipoCuenta.banco => Iconos.banco,
    TipoCuenta.billetera => Iconos.billetera,
    TipoCuenta.efectivo => Iconos.efectivo,
  };
}

class _TuSueldo extends StatelessWidget {
  const _TuSueldo({required this.pago});

  final ProximoPago pago;

  @override
  Widget build(BuildContext context) {
    final fecha = pago.fecha;
    final hasta = pago.fechaHasta;
    final cuando = fecha == null
        ? null
        : hasta != null && hasta != fecha
        ? '${fecha.day}–${_diaYMes(hasta)}'
        : _diaYMes(fecha);

    return Seccion(
      titulo: 'Tu sueldo',
      child: Panel.lista(
        filas: [
          Fila(
            inicio: const IconoCaja(Iconos.dolar),
            titulo: fecha == null
                ? pago.titulo
                : '${pago.titulo} · ${Formato.nombreDeMes(fecha.month).toLowerCase()}',
            subtitulo: pago.detalle.isEmpty ? null : pago.detalle,
            importe: pago.monto,
            importeConSigno: true,
            debajoDelImporte: cuando,
            alTocar: () => context.push(Rutas.sueldo),
          ),
        ],
      ),
    );
  }
}

class _Modulos extends StatelessWidget {
  const _Modulos({required this.modulos});

  final Set<Modulo> modulos;

  @override
  Widget build(BuildContext context) {
    return Seccion(
      titulo: 'Más',
      child: Panel.lista(
        filas: [
          for (final m in Modulo.values.where(modulos.contains))
            Fila(
              inicio: IconoCaja(
                m == Modulo.ahorro
                    ? Iconos.ahorro
                    : Iconos.deCategoria(CategoriaGasto.transporte),
              ),
              titulo: m.nombre,
              final_: Icon(Iconos.entrar, color: context.colores.tinta3),
              alTocar: () => context.push(
                m == Modulo.ahorro ? Rutas.ahorro : Rutas.transporte,
              ),
            ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.alReintentar});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Iconos.sinConexion,
      titulo: 'No se pudo abrir el inicio',
      texto: mensaje,
      accion: 'Reintentar',
      alTocarAccion: alReintentar,
    );
  }
}

// --- textos ---

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _mesCorto(int mes) => _meses[mes - 1];

String _diaYMes(DateTime f) => '${f.day} ${_mesCorto(f.month)}';

/// «A, B y C».
String _lista(Iterable<String> partes) {
  final l = partes.toList();
  if (l.length <= 1) return l.join();
  return '${l.sublist(0, l.length - 1).join(', ')} y ${l.last}';
}

/// Sin lo que va entre paréntesis: «Tarjeta Nu (corte 14 nov)» → «Tarjeta Nu».
String _corto(String titulo) =>
    titulo.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

/// «Mi plan» en una frase: cuánto sobra el próximo mes y cuándo llega la meta. Lleva al plan.
class _MiPlan extends ConsumerWidget {
  const _MiPlan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider).valueOrNull;
    final proximo = plan?.proximo;
    if (plan == null || proximo == null) return const SizedBox.shrink();
    final textos = Theme.of(context).textTheme;
    final c = context.colores;
    final meta = plan.metas.isEmpty ? null : plan.metas.first;
    final mes = Formato.nombreDeMes(proximo.periodo.month).toLowerCase();
    final restar = ref.watch(restarDiaADiaProvider);
    final sobra = sobraSegun(proximo, restarDiaADia: restar);

    return Seccion(
      titulo: 'Mi plan',
      accion: 'Ver',
      alTocarAccion: () => context.push(Rutas.plan),
      child: Panel(
        child: InkWell(
          onTap: () => context.push(Rutas.plan),
          child: Row(
            children: [
              IlustracionMeta(progreso: meta?.progreso ?? 0.15, alto: 72),
              const SizedBox(width: Espacio.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sobra < 0
                          ? 'En $mes te faltan ${Formato.pesos(-sobra)}'
                          : 'En $mes te sobran ${Formato.pesos(sobra)}',
                      style: textos.titleMedium,
                    ),
                    Text(
                      restar
                          ? 'después de pagar todo y el día a día'
                          : 'después de pagar gastos fijos y deudas',
                      style: textos.bodySmall?.copyWith(color: c.tinta2),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: Espacio.s),
                      Text(
                        meta.faltan <= 0
                            ? '${meta.nombre}: ¡completa!'
                            : meta.alcanzaEn == null
                            ? '${meta.nombre}: no alcanza este año'
                            : '${meta.nombre}: '
                                  '${Formato.mesEnFrase(meta.alcanzaEn!)}',
                        style: textos.bodyMedium?.copyWith(
                          color: colorBorgona,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
