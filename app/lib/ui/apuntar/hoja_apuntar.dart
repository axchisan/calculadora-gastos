import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/modelos.dart';
import '../../dominio/movimientos.dart';
import '../../estado/compras.dart';
import '../../estado/mes.dart';
import '../../estado/movimientos.dart';
import '../comun/iconos.dart';

/// Qué se apunta.
enum TipoApunte {
  compra('Compra'),
  ingreso('Ingreso'),
  gasto('Gasto fijo');

  const TipoApunte(this.etiqueta);

  final String etiqueta;
}

/// La hoja única para apuntar: una compra del día a día, un ingreso o un gasto fijo del mes.
///
/// El importe se escribe con un teclado propio, grande y siempre a la vista, porque es lo que se
/// teclea casi siempre; el teclado del sistema solo sale para escribir qué fue. También sirve para
/// corregir un ingreso o una compra ya apuntados ([editando]).
class HojaApuntar extends ConsumerStatefulWidget {
  const HojaApuntar({
    required this.mesId,
    required this.periodo,
    this.tipoInicial = TipoApunte.compra,
    this.editando,
    super.key,
  });

  final String mesId;

  /// Mes presupuestal (día uno del mes que le da nombre): limita la fecha.
  final DateTime periodo;
  final TipoApunte tipoInicial;
  final Movimiento? editando;

  /// Abre la hoja. Devuelve true si se guardó algo.
  static Future<bool> abrir(
    BuildContext context, {
    required String mesId,
    required DateTime periodo,
    TipoApunte tipo = TipoApunte.compra,
    Movimiento? editando,
  }) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => HojaApuntar(
        mesId: mesId,
        periodo: periodo,
        tipoInicial: tipo,
        editando: editando,
      ),
    );
    return guardado ?? false;
  }

  @override
  ConsumerState<HojaApuntar> createState() => _EstadoHojaApuntar();
}

class _EstadoHojaApuntar extends ConsumerState<HojaApuntar> {
  late TipoApunte _tipo = widget.tipoInicial;
  String _cifras = '';
  final _que = TextEditingController();
  final _nota = TextEditingController();
  bool _conNota = false;
  CategoriaGasto _categoria = CategoriaGasto.alimentacion;
  TipoIngreso _tipoIngreso = TipoIngreso.trabajo;
  MedioPago _medio = MedioPago.efectivo;
  String? _tarjetaId;
  bool _yaPagado = true;
  late DateTime _fecha;
  bool _guardando = false;

  DateTime get _inicio =>
      DateTime(widget.periodo.year, widget.periodo.month - 1, 28);
  DateTime get _fin => DateTime(widget.periodo.year, widget.periodo.month, 27);

  bool get _editando => widget.editando != null;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    // Hoy, si cae dentro del mes; si no, el último día del mes que se está viendo.
    _fecha = dia.isBefore(_inicio) || dia.isAfter(_fin) ? _fin : dia;

    final m = widget.editando;
    if (m != null) {
      _tipo = m.tipo == TipoMovimiento.ingreso
          ? TipoApunte.ingreso
          : TipoApunte.compra;
      _cifras = m.monto.abs().round().toString();
      _que.text = m.titulo;
      _fecha = m.fecha;
      _nota.text = m.notas ?? '';
      _conNota = _nota.text.isNotEmpty;
      if (m.tipoIngreso case final t?) _tipoIngreso = t;
      if (m.categoriaGasto case final c?) _categoria = c;
      if (m.etiqueta == 'CREDITO') _medio = MedioPago.credito;
      if (m.detalle == MedioPago.debito.etiqueta) _medio = MedioPago.debito;
    }
  }

  @override
  void dispose() {
    _que.dispose();
    _nota.dispose();
    super.dispose();
  }

  double get _monto => double.tryParse(_cifras) ?? 0;

  void _tecla(String t) {
    setState(() {
      if (t == '⌫') {
        if (_cifras.isNotEmpty) {
          _cifras = _cifras.substring(0, _cifras.length - 1);
        }
      } else {
        _cifras = (_cifras + t).replaceFirst(RegExp(r'^0+'), '');
        if (_cifras.length > 10) _cifras = _cifras.substring(0, 10);
      }
    });
  }

  List<CategoriaGasto> get _categorias => _tipo == TipoApunte.compra
      ? CategoriaGasto.deCompras
      : CategoriaGasto.values;

  List<String> get _sugerencias {
    if (_editando) return const [];
    return switch (_tipo) {
      TipoApunte.compra =>
        ref
            .watch(comprasProvider)
            .maybeWhen(
              data: (d) {
                final veces = <String, int>{};
                for (final c in d.compras) {
                  veces.update(c.descripcion, (n) => n + 1, ifAbsent: () => 1);
                }
                return (veces.keys.toList()
                      ..sort((a, b) => veces[b]!.compareTo(veces[a]!)))
                    .take(6)
                    .toList();
              },
              orElse: () => const <String>[],
            ),
      TipoApunte.ingreso =>
        ref
            .watch(mesProvider)
            .maybeWhen(
              data: (d) =>
                  d.ingresos.map((i) => i.concepto).toSet().take(4).toList(),
              orElse: () => const <String>[],
            ),
      TipoApunte.gasto => const <String>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final tarjetas = ref.watch(tarjetasDeCreditoProvider);
    final sugerencias = _sugerencias;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        // Con la barra de gestos del sistema abajo, el botón de guardar no debe quedar debajo.
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editando ? 'Corregir' : 'Apuntar',
              style: textos.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Espacio.m),
            if (!_editando)
              SegmentedButton<TipoApunte>(
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                segments: [
                  for (final t in TipoApunte.values)
                    ButtonSegment(value: t, label: Text(t.etiqueta)),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
            const SizedBox(height: Espacio.l),
            Semantics(
              label: 'Importe ${Formato.pesos(_monto)}',
              excludeSemantics: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: r'$',
                      style: Tipo.estilo(26, 600, color: c.tinta3),
                    ),
                    TextSpan(
                      text: Formato.numero(_monto),
                      style: textos.displayLarge?.copyWith(
                        color: _tipo == TipoApunte.ingreso
                            ? c.positivo
                            : c.tinta,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Espacio.l),
            TextField(
              controller: _que,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: switch (_tipo) {
                  TipoApunte.compra => '¿Qué fue?',
                  TipoApunte.ingreso => '¿De dónde vino?',
                  TipoApunte.gasto => '¿Qué gasto es?',
                },
              ),
            ),
            if (sugerencias.isNotEmpty) ...[
              const SizedBox(height: Espacio.s),
              _Desplazable(
                hijos: [
                  for (final s in sugerencias)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() => _que.text = s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Espacio.l),
            _Etiqueta(_tipo == TipoApunte.ingreso ? 'Tipo' : 'Categoría'),
            if (_tipo == TipoApunte.ingreso)
              _Desplazable(
                hijos: [
                  for (final t in TipoIngreso.alApuntar)
                    ChoiceChip(
                      avatar: Icon(
                        Iconos.deIngreso(t),
                        size: 18,
                        color: _tipoIngreso == t ? c.sobreAcento : c.tinta2,
                      ),
                      label: Text(t.etiqueta),
                      selected: _tipoIngreso == t,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _tipoIngreso = t),
                    ),
                ],
              )
            else
              _Desplazable(
                hijos: [
                  for (final cat in _categorias)
                    ChoiceChip(
                      avatar: Icon(
                        Iconos.deCategoria(cat),
                        size: 18,
                        color: _categoria == cat ? c.sobreAcento : c.tinta2,
                      ),
                      label: Text(cat.etiqueta),
                      selected: _categoria == cat,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _categoria = cat),
                    ),
                ],
              ),
            if (_tipo == TipoApunte.compra) ...[
              const SizedBox(height: Espacio.l),
              const _Etiqueta('Pagaste con'),
              _Desplazable(
                hijos: [
                  for (final medio in [MedioPago.efectivo, MedioPago.debito])
                    ChoiceChip(
                      label: Text(medio.etiqueta),
                      selected: _medio == medio,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _medio = medio;
                        _tarjetaId = null;
                      }),
                    ),
                  for (final t in tarjetas)
                    ChoiceChip(
                      avatar: Icon(
                        Iconos.tarjeta,
                        size: 18,
                        color:
                            _medio == MedioPago.credito &&
                                (_tarjetaId == t.id ||
                                    (_tarjetaId == null &&
                                        tarjetas.length == 1))
                            ? c.sobreAcento
                            : c.tinta2,
                      ),
                      label: Text(t.nombre),
                      selected:
                          _medio == MedioPago.credito &&
                          (_tarjetaId == t.id ||
                              (_tarjetaId == null && tarjetas.length == 1)),
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _medio = MedioPago.credito;
                        _tarjetaId = t.id;
                      }),
                    ),
                ],
              ),
            ],
            if (_tipo == TipoApunte.gasto && !_editando)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ya está pagado'),
                subtitle: const Text(
                  'Si no, queda en «Por pagar» hasta que lo marques',
                ),
                value: _yaPagado,
                onChanged: (v) => setState(() => _yaPagado = v),
              ),
            const SizedBox(height: Espacio.m),
            Wrap(
              spacing: Espacio.s,
              runSpacing: Espacio.s,
              children: [
                if (_tipo != TipoApunte.gasto)
                  ActionChip(
                    avatar: const Icon(Iconos.calendario, size: 18),
                    label: Text(_textoFecha(_fecha)),
                    onPressed: _elegirFecha,
                  ),
                if (!_conNota)
                  ActionChip(
                    avatar: const Icon(Iconos.editar, size: 18),
                    label: const Text('Añadir una nota'),
                    onPressed: () => setState(() => _conNota = true),
                  ),
              ],
            ),
            if (_conNota) ...[
              const SizedBox(height: Espacio.s),
              TextField(
                controller: _nota,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Nota'),
              ),
            ],
            const SizedBox(height: Espacio.l),
            _Teclado(alPulsar: _tecla),
            const SizedBox(height: Espacio.l),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _inicio,
      lastDate: _fin,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    final mensajero = ScaffoldMessenger.of(context);
    if (_monto <= 0) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('Escribe cuánto fue')),
      );
      return;
    }
    final que = _que.text.trim().isEmpty
        ? (_tipo == TipoApunte.ingreso
              ? _tipoIngreso.etiqueta
              : _categoria.etiqueta)
        : _que.text.trim();
    final nota = _conNota && _nota.text.trim().isNotEmpty
        ? _nota.text.trim()
        : null;

    setState(() => _guardando = true);
    final meses = ref.read(repositorioMesesProvider);
    final compras = ref.read(repositorioComprasProvider);
    final tarjetas = ref.read(tarjetasDeCreditoProvider);
    try {
      final editando = widget.editando;
      if (editando != null && editando.id != null) {
        if (editando.tipo == TipoMovimiento.ingreso) {
          await meses.editarIngreso(
            editando.id!,
            concepto: que,
            monto: _monto,
            fecha: _fecha,
            tipo: _tipoIngreso,
            notas: nota ?? '',
          );
        } else {
          await compras.actualizar(
            editando.id!,
            descripcion: que,
            monto: _monto,
            categoria: _categoria,
            fecha: _fecha,
            medio: _medio,
            tarjetaId: _medio == MedioPago.credito
                ? _tarjetaElegida(tarjetas)
                : null,
            nota: nota ?? '',
          );
        }
      } else {
        switch (_tipo) {
          case TipoApunte.compra:
            await compras.registrar(
              widget.mesId,
              descripcion: que,
              monto: _monto,
              categoria: _categoria,
              fecha: _fecha,
              medio: _medio,
              tarjetaId: _medio == MedioPago.credito
                  ? _tarjetaElegida(tarjetas)
                  : null,
              nota: nota,
            );
          case TipoApunte.ingreso:
            await meses.crearIngreso(
              widget.mesId,
              concepto: que,
              monto: _monto,
              fecha: _fecha,
              recibido: true,
              tipo: _tipoIngreso,
              notas: nota,
            );
          case TipoApunte.gasto:
            final gasto = await meses.crearGasto(
              widget.mesId,
              nombre: que,
              categoria: _categoria,
              monto: _monto,
              notas: nota,
            );
            if (_yaPagado) {
              await meses.marcarPagado(
                gasto.id,
                actual: gasto,
                mesId: widget.mesId,
              );
            }
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            _editando
                ? 'Corregido: $que'
                : 'Apuntado: $que · ${Formato.pesos(_monto)}',
          ),
        ),
      );
      await refrescarSecciones(ref);
    } on ErrorApi catch (e) {
      if (mounted) setState(() => _guardando = false);
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  String? _tarjetaElegida(List<Tarjeta> tarjetas) =>
      _tarjetaId ?? (tarjetas.length == 1 ? tarjetas.first.id : null);

  String _textoFecha(DateTime f) {
    final hoy = DateTime.now();
    if (f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
      return 'Hoy';
    }
    return Formato.fechaCorta(f);
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Espacio.s),
    child: Text(texto, style: Theme.of(context).textTheme.labelMedium),
  );
}

/// Una fila de pastillas que se desliza de lado en lugar de ocupar varias líneas.
class _Desplazable extends StatelessWidget {
  const _Desplazable({required this.hijos});

  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < hijos.length; i++) ...[
          if (i > 0) const SizedBox(width: Espacio.s),
          hijos[i],
        ],
      ],
    ),
  );
}

/// Teclado numérico de la hoja. «000» porque en pesos casi todo termina en miles.
class _Teclado extends StatelessWidget {
  const _Teclado({required this.alPulsar});

  final void Function(String) alPulsar;

  static const _teclas = [
    '1', '2', '3', //
    '4', '5', '6',
    '7', '8', '9',
    '000', '0', '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: Espacio.s,
      crossAxisSpacing: Espacio.s,
      children: [
        for (final t in _teclas)
          Material(
            color: c.superficie2,
            borderRadius: BorderRadius.circular(Radios.medio),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radios.medio),
              onTap: () => alPulsar(t),
              child: Center(
                child: t == '⌫'
                    ? Icon(
                        Iconos.retroceso,
                        color: c.tinta,
                        semanticLabel: 'Borrar',
                      )
                    : Text(t, style: Tipo.estilo(22, 600, color: c.tinta)),
              ),
            ),
          ),
      ],
    );
  }
}
