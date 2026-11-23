import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/modelos.dart';
import '../../dominio/movimientos.dart';
import '../../estado/compras.dart';
import '../../estado/detectados.dart';
import '../../estado/mes.dart';
import '../../estado/movimientos.dart';
import '../../estado/proveedores.dart';
import '../apuntar/hoja_apuntar.dart';
import '../comun/componentes.dart';
import '../comun/deshacer.dart';
import '../comun/iconos.dart';
import '../mes/pantalla_mes.dart';
import '../mes/widgets/editor_gasto.dart';

/// Movimientos: todo lo que entró y salió en el mes, en una sola lista por día.
///
/// Arriba, lo que falta pagar con un botón para pagarlo; debajo, la línea de tiempo con
/// ingresos, gastos fijos pagados, compras, pagos de deudas y cuotas. Un solo «+» apunta
/// cualquier cosa. Lo que la lista suma es el disponible del mes.
class PantallaMovimientos extends ConsumerStatefulWidget {
  const PantallaMovimientos({super.key});

  @override
  ConsumerState<PantallaMovimientos> createState() => _EstadoMovimientos();
}

class _EstadoMovimientos extends ConsumerState<PantallaMovimientos> {
  bool _buscando = false;
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(movimientosProvider);
    final periodo = ref.watch(periodoProvider);
    final textos = Theme.of(context).textTheme;
    final c = context.colores;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espacio.lateral, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Movimientos', style: textos.headlineSmall),
                  ),
                  IconButton(
                    tooltip: _buscando ? 'Cerrar búsqueda' : 'Buscar',
                    icon: Icon(_buscando ? Iconos.cerrar : Iconos.buscar),
                    onPressed: () => setState(() {
                      _buscando = !_buscando;
                      if (!_buscando) _busqueda.clear();
                    }),
                  ),
                  TextButton.icon(
                    onPressed: () => PantallaMes.elegirMes(context, ref),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Iconos.desplegar, size: 18),
                    label: Text(_mesCorto(periodo), style: textos.labelLarge),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    onSelected: (o) => switch (o) {
                      'mes' => context.push(Rutas.detalleMes),
                      'dia' => context.push(Rutas.diario),
                      'banco' => context.push(Rutas.porRevisar),
                      _ => null,
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'banco',
                        child: Text('Lo que llegó del banco'),
                      ),
                      PopupMenuItem(
                        value: 'mes',
                        child: Text('Sueldo, gastos fijos y cierre del mes'),
                      ),
                      PopupMenuItem(
                        value: 'dia',
                        child: Text('Compras del día a día y tarjetas'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_buscando)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacio.lateral,
                  4,
                  Espacio.lateral,
                  4,
                ),
                child: TextField(
                  controller: _busqueda,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, categoría o nota',
                    prefixIcon: Icon(Iconos.buscar),
                  ),
                ),
              ),
            Expanded(
              child: datos.when(
                skipLoadingOnRefresh: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EstadoVacio(
                  icono: Iconos.sinConexion,
                  titulo: 'No se pudieron cargar los movimientos',
                  texto: e is ErrorApi ? e.mensaje : 'Inténtalo de nuevo',
                  accion: 'Reintentar',
                  alTocarAccion: () => ref.invalidate(movimientosProvider),
                ),
                data: (d) => _Lista(datos: d, busqueda: _busqueda.text),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: datos.hasValue && !datos.requireValue.cerrado
          ? FloatingActionButton(
              tooltip: 'Apuntar',
              onPressed: () => HojaApuntar.abrir(
                context,
                mesId: datos.requireValue.mesId,
                periodo: datos.requireValue.periodo,
              ),
              child: Icon(Iconos.anadir, color: c.sobreAcento),
            )
          : null,
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({required this.datos, required this.busqueda});

  final MovimientosDelMes datos;
  final String busqueda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroMovimientosProvider);
    final ocultos = ref.watch(ocultosProvider);
    final visibles = MovimientosDelMes(
      mesId: datos.mesId,
      periodo: datos.periodo,
      cerrado: datos.cerrado,
      entro: datos.entro,
      salio: datos.salio,
      queda: datos.queda,
      porPagar: datos.porPagar.sinOcultos(ocultos, (p) => p.id),
      movimientos: datos.movimientos.sinOcultos(
        ocultos,
        (m) => m.id ?? '${m.tipo.codigo}-${m.titulo}',
      ),
    );
    final dias = visibles.porDia(filtro: filtro, busqueda: busqueda);
    final textos = Theme.of(context).textTheme;
    final c = context.colores;
    final ancho = Pantalla.esEscritorio(context) ? 680.0 : double.infinity;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(clienteApiProvider).revisarTodo();
        await ref.refresh(movimientosProvider.future).catchError((_) => datos);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lateral,
              Espacio.s,
              Espacio.lateral,
              96,
            ),
            children: [
              _Resumen(datos: datos),
              const _AvisoPorRevisar(),
              if (datos.cerrado) ...[
                const SizedBox(height: Espacio.m),
                const CajaAviso(
                  tono: Tono.suave,
                  texto: TextSpan(
                    text:
                        'Este mes está cerrado. Para cambiar algo, reábrelo desde '
                        '«Sueldo, gastos fijos y cierre del mes».',
                  ),
                ),
              ],
              if (visibles.porPagar.isNotEmpty && busqueda.isEmpty)
                Seccion(
                  titulo: 'Por pagar este mes',
                  arriba: Espacio.xl,
                  child: Panel.lista(
                    filas: [
                      for (final p in visibles.porPagar)
                        _FilaPorPagar(
                          pago: p,
                          mesId: datos.mesId,
                          bloqueado: datos.cerrado,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: Espacio.xl),
              SegmentedButton<FiltroMovimientos>(
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                segments: const [
                  ButtonSegment(
                    value: FiltroMovimientos.todo,
                    label: Text('Todo'),
                  ),
                  ButtonSegment(
                    value: FiltroMovimientos.entradas,
                    label: Text('Entradas'),
                  ),
                  ButtonSegment(
                    value: FiltroMovimientos.salidas,
                    label: Text('Salidas'),
                  ),
                ],
                selected: {filtro},
                onSelectionChanged: (s) =>
                    ref.read(filtroMovimientosProvider.notifier).state =
                        s.first,
              ),
              if (dias.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    busqueda.isNotEmpty
                        ? 'Nada coincide con «$busqueda».'
                        : datos.movimientos.isEmpty
                        ? 'Aún no hay movimientos este mes. Toca + para apuntar.'
                        : 'No hay movimientos con este filtro.',
                    textAlign: TextAlign.center,
                    style: textos.bodyMedium?.copyWith(color: c.tinta2),
                  ),
                ),
              for (final dia in dias) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${Formato.diaDeLaSemana(dia.fecha)} '
                          '${dia.fecha.day} ${_mesCorto(dia.fecha)}',
                          style: textos.labelMedium,
                        ),
                      ),
                      Text(
                        Formato.pesosConSigno(dia.neto),
                        style: textos.labelMedium,
                      ),
                    ],
                  ),
                ),
                Panel.lista(
                  filas: [
                    for (final m in dia.movimientos)
                      _FilaMovimiento(movimiento: m, datos: datos),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.datos});

  final MovimientosDelMes datos;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;

    Widget cifra(String etiqueta, String valor, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: textos.bodySmall?.copyWith(color: c.tinta2)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: textos.titleMedium?.copyWith(color: color ?? c.tinta),
            ),
          ),
        ],
      ),
    );

    return Panel(
      child: Row(
        children: [
          cifra('Entró', '+${Formato.pesos(datos.entro)}', color: c.positivo),
          cifra('Salió', Formato.pesos(datos.salio)),
          cifra(
            'Queda',
            Formato.pesos(datos.queda),
            color: datos.queda < 0 ? c.negativo : null,
          ),
        ],
      ),
    );
  }
}

class _FilaPorPagar extends ConsumerWidget {
  const _FilaPorPagar({
    required this.pago,
    required this.mesId,
    required this.bloqueado,
  });

  final PorPagar pago;
  final String mesId;
  final bool bloqueado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partes = [
      pago.categoria.etiqueta,
      if (pago.vence != null)
        'vence el ${pago.vence!.day} ${_mesCorto(pago.vence!)}',
      if (pago.vence == null && pago.fijo) 'gasto fijo',
      if (pago.pendiente < pago.monto)
        'falta ${Formato.pesos(pago.pendiente)} de ${Formato.pesos(pago.monto)}',
    ];
    return Fila(
      inicio: IconoCaja(Iconos.deCategoria(pago.categoria)),
      titulo: pago.nombre,
      etiqueta: pago.enCola ? const Etiqueta('Sin subir') : null,
      subtitulo: partes.join(' · '),
      final_: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Importe(pago.pendiente, colorear: false),
          const SizedBox(width: Espacio.s),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: bloqueado || pago.enCola
                ? null
                : () => _pagar(context, ref),
            child: const Text('Pagar'),
          ),
        ],
      ),
      alTocar: bloqueado || pago.enCola ? null : () => _opciones(context, ref),
    );
  }

  Future<void> _pagar(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    final gasto = _gasto(ref);
    try {
      await ref
          .read(repositorioMesesProvider)
          .marcarPagado(pago.id, actual: gasto, mesId: mesId);
      mensajero.showSnackBar(
        SnackBar(content: Text('${pago.nombre} quedó pagado')),
      );
      await refrescarSecciones(ref);
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Gasto? _gasto(WidgetRef ref) => ref
      .read(mesProvider)
      .valueOrNull
      ?.gastos
      .where((g) => g.id == pago.id)
      .firstOrNull;

  Future<void> _opciones(BuildContext context, WidgetRef ref) async {
    final opcion = await abrirHoja<String>(
      context,
      titulo: pago.nombre,
      subtitulo: 'Falta ${Formato.pesos(pago.pendiente)}',
      contenido: (ctx) => Panel.lista(
        filas: [
          Fila(
            inicio: const IconoCaja(Iconos.listo),
            titulo: 'Pagar todo',
            alTocar: () => Navigator.pop(ctx, 'pagar'),
          ),
          Fila(
            inicio: const IconoCaja(Iconos.editar),
            titulo: 'Editar',
            alTocar: () => Navigator.pop(ctx, 'editar'),
          ),
          Fila(
            inicio: const IconoCaja(Iconos.borrar),
            titulo: 'Eliminar del mes',
            alTocar: () => Navigator.pop(ctx, 'eliminar'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    final repositorio = ref.read(repositorioMesesProvider);
    switch (opcion) {
      case 'pagar':
        await _pagar(context, ref);
      case 'editar':
        final gasto = _gasto(ref);
        if (gasto == null) return;
        final cambios = await EditorGasto.abrir(context, gasto);
        if (cambios == null || !context.mounted) return;
        try {
          await repositorio.actualizarGasto(
            gasto.id,
            nombre: cambios.nombre,
            categoria: cambios.categoria,
            monto: cambios.monto,
            diaVencimiento: cambios.diaVencimiento,
          );
          await refrescarSecciones(ref);
        } on ErrorApi catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.mensaje)));
          }
        }
      case 'eliminar':
        await borrarConDeshacer(
          context,
          ref,
          id: pago.id,
          mensaje: 'Eliminaste «${pago.nombre}»',
          borrar: () async {
            await repositorio.eliminarGasto(pago.id);
            await refrescarSecciones(ref);
          },
        );
    }
  }
}

class _FilaMovimiento extends ConsumerWidget {
  const _FilaMovimiento({required this.movimiento, required this.datos});

  final Movimiento movimiento;
  final MovimientosDelMes datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = movimiento;
    final c = context.colores;
    final partes = [
      m.etiquetaCategoria,
      ?m.detalle,
      ?m.notas,
    ].where((p) => p.isNotEmpty).toList();

    return Fila(
      inicio: IconoCaja(_icono(m), color: m.entra ? c.positivo : null),
      titulo: m.titulo,
      etiqueta: m.pendiente
          ? const Etiqueta('Sin subir')
          : switch (m.etiqueta) {
              'PRESTAMO' => const Etiqueta('Préstamo'),
              'FIJO' => const Etiqueta('Fijo'),
              'CREDITO' => const Etiqueta('Crédito', tono: Tono.aviso),
              _ => null,
            },
      subtitulo: partes.join(' · '),
      importe: m.monto,
      importeConSigno: m.entra,
      alTocar: () => _detalle(context, ref),
    );
  }

  static IconData _icono(Movimiento m) => switch (m.tipo) {
    TipoMovimiento.sueldo => Iconos.dolar,
    TipoMovimiento.ingreso => Iconos.deIngreso(m.tipoIngreso!),
    TipoMovimiento.ahorro => Iconos.ahorro,
    _ when m.esCobro => Iconos.familia,
    _ => Iconos.deCategoria(m.categoriaGasto ?? CategoriaGasto.otro),
  };

  Future<void> _detalle(BuildContext context, WidgetRef ref) async {
    final m = movimiento;
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final editable =
        !datos.cerrado &&
        !m.pendiente &&
        m.id != null &&
        (m.tipo == TipoMovimiento.ingreso || m.tipo == TipoMovimiento.compra);
    final borrable =
        !datos.cerrado &&
        !m.pendiente &&
        m.id != null &&
        (m.tipo == TipoMovimiento.ingreso ||
            m.tipo == TipoMovimiento.compra ||
            m.tipo == TipoMovimiento.gasto);

    final accion = await abrirHoja<String>(
      context,
      titulo: m.titulo,
      contenido: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.entra
                ? Formato.pesosConSigno(m.monto)
                : Formato.dinero(m.monto.abs()),
            style: textos.displayMedium?.copyWith(
              color: m.entra ? c.positivo : c.tinta,
            ),
          ),
          const SizedBox(height: Espacio.l),
          Panel.lista(
            filas: [
              _Dato(
                'Fecha',
                '${Formato.diaDeLaSemana(m.fecha)} ${Formato.fecha(m.fecha)}',
              ),
              _Dato(
                m.tipo == TipoMovimiento.ingreso ? 'Tipo' : 'Categoría',
                m.etiquetaCategoria,
              ),
              if (m.detalle != null) _Dato('Detalle', m.detalle!),
              if (m.notas != null) _Dato('Nota', m.notas!),
              if (!m.cuenta)
                const _Dato(
                  'Cuándo sale',
                  'Con el pago de la tarjeta, no este mes',
                ),
            ],
          ),
          const SizedBox(height: Espacio.l),
          if (editable)
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(ctx, 'editar'),
              icon: const Icon(Iconos.editar),
              label: const Text('Corregir'),
            ),
          if (m.tipo == TipoMovimiento.gasto && !datos.cerrado && !m.pendiente)
            Padding(
              padding: const EdgeInsets.only(top: Espacio.s),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'despagar'),
                child: const Text('No lo he pagado'),
              ),
            ),
          if (_destino(m) case (final etiqueta, _))
            Padding(
              padding: const EdgeInsets.only(top: Espacio.s),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'ir'),
                child: Text(etiqueta),
              ),
            ),
          if (borrable)
            Padding(
              padding: const EdgeInsets.only(top: Espacio.s),
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: c.negativo),
                onPressed: () => Navigator.pop(ctx, 'eliminar'),
                icon: const Icon(Iconos.borrar),
                label: const Text('Eliminar'),
              ),
            ),
        ],
      ),
    );
    if (accion == null || !context.mounted) return;

    final meses = ref.read(repositorioMesesProvider);
    final compras = ref.read(repositorioComprasProvider);
    try {
      switch (accion) {
        case 'editar':
          await HojaApuntar.abrir(
            context,
            mesId: datos.mesId,
            periodo: datos.periodo,
            editando: m,
          );
        case 'despagar':
          await meses.marcarPendiente(m.id!);
          await refrescarSecciones(ref);
        case 'ir':
          final (_, ruta) = _destino(m)!;
          if (ruta == Rutas.deudas) {
            context.go(ruta);
          } else {
            context.push(ruta);
          }
        case 'eliminar':
          await borrarConDeshacer(
            context,
            ref,
            id: m.id!,
            mensaje: 'Eliminaste «${m.titulo}»',
            borrar: () async {
              switch (m.tipo) {
                case TipoMovimiento.ingreso:
                  await meses.eliminarIngreso(m.id!);
                case TipoMovimiento.compra:
                  await compras.eliminar(m.id!);
                default:
                  await meses.eliminarGasto(m.id!);
              }
              await refrescarSecciones(ref);
            },
          );
      }
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  /// A dónde llevar lo que no se edita aquí.
  static (String, String)? _destino(Movimiento m) => switch (m.tipo) {
    TipoMovimiento.abono ||
    TipoMovimiento.cuota ||
    TipoMovimiento.tarjeta => ('Ver en Deudas', Rutas.deudas),
    TipoMovimiento.sueldo => ('Ver Mi sueldo', Rutas.sueldo),
    TipoMovimiento.ahorro => ('Ver Metas de ahorro', Rutas.ahorro),
    _ => null,
  };
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              etiqueta,
              style: textos.bodyMedium?.copyWith(color: context.colores.tinta2),
            ),
          ),
          Expanded(child: Text(valor, style: textos.bodyMedium)),
        ],
      ),
    );
  }
}

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _mesCorto(DateTime f) => _meses[f.month - 1];

/// «N movimientos del banco por revisar»: lleva a la bandeja. No ocupa nada si no hay.
class _AvisoPorRevisar extends ConsumerWidget {
  const _AvisoPorRevisar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuantos = ref.watch(cuantosPorRevisarProvider);
    if (cuantos == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.m),
      child: Panel.lista(
        filas: [
          Fila(
            inicio: const IconoCaja(Iconos.banco),
            titulo: cuantos == 1
                ? '1 movimiento por revisar'
                : '$cuantos movimientos por revisar',
            subtitulo: 'Llegaron del banco y no están en la app',
            final_: const Icon(Iconos.entrar),
            alTocar: () => context.push(Rutas.porRevisar),
          ),
        ],
      ),
    );
  }
}
