import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dinero.dart';
import '../../../core/formato.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/compras.dart';

/// Lo que devuelve el formulario al confirmarse.
class DatosCompra {
  const DatosCompra({
    required this.descripcion,
    required this.monto,
    required this.categoria,
    required this.fecha,
    required this.medio,
    this.tarjetaId,
  });

  final String descripcion;
  final double monto;
  final CategoriaGasto categoria;
  final DateTime fecha;
  final MedioPago medio;
  final String? tarjetaId;
}

/// Registro rápido de una compra del día a día.
///
/// El orden de los campos está pensado para escribir sin pensar: primero el importe, que es lo
/// único que siempre hay que teclear, y después el resto, que casi siempre se resuelve con un
/// toque. Si apuntar una gaseosa costara más de unos segundos, se dejaría de apuntar.
class FormularioCompra extends ConsumerStatefulWidget {
  const FormularioCompra({
    required this.periodo,
    this.compra,
    this.inicial,
    this.sugerencias = const [],
    super.key,
  });

  /// Mes presupuestal al que se imputa la compra.
  ///
  /// La fecha puede ser de ese mes o del anterior: quien cobra el 28 imputa a septiembre lo que
  /// compra desde esa fecha, aunque el calendario diga agosto.
  final DateTime periodo;

  /// Si se pasa, el formulario edita esa compra en lugar de crear una nueva.
  final Compra? compra;

  /// Valores de partida para una compra nueva.
  ///
  /// Lo usa la bandeja de pagos capturados: el importe, el comercio y la tarjeta ya vienen de
  /// la notificación, así que al usuario solo le queda elegir la categoría.
  final DatosCompra? inicial;

  /// Descripciones ya usadas este mes, para repetir una compra habitual de un toque.
  final List<String> sugerencias;

  @override
  ConsumerState<FormularioCompra> createState() => _FormularioCompraState();
}

class _FormularioCompraState extends ConsumerState<FormularioCompra> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _monto;
  late final TextEditingController _descripcion;

  late CategoriaGasto _categoria;
  late MedioPago _medio;
  late DateTime _fecha;
  String? _tarjetaId;

  bool get _editando => widget.compra != null;

  @override
  void initState() {
    super.initState();
    final compra = widget.compra;
    final inicial = widget.inicial;

    _monto = TextEditingController(
      text: compra != null
          ? Dinero.paraEditar(compra.monto)
          : inicial != null
          ? Dinero.paraEditar(inicial.monto)
          : '',
    );
    _descripcion = TextEditingController(
      text: compra?.descripcion ?? inicial?.descripcion ?? '',
    );
    _categoria =
        compra?.categoria ?? inicial?.categoria ?? CategoriaGasto.antojos;
    _medio = compra?.medio ?? inicial?.medio ?? MedioPago.efectivo;
    _tarjetaId = compra?.tarjetaId ?? inicial?.tarjetaId;
    _fecha = compra?.fecha ?? inicial?.fecha ?? _hoyDentroDelMes();
  }

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  /// Hoy si el mes en pantalla es el actual; si no, el día uno de ese mes.
  ///
  /// Al apuntar en un mes pasado no tendría sentido proponer la fecha de hoy: el servidor la
  /// rechazaría por caer fuera del mes.
  DateTime _hoyDentroDelMes() {
    final hoy = DateTime.now();
    final esElMesEnCurso =
        hoy.year == widget.periodo.year && hoy.month == widget.periodo.month;
    return esElMesEnCurso
        ? DateTime(hoy.year, hoy.month, hoy.day)
        : DateTime(widget.periodo.year, widget.periodo.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tarjetas = ref.watch(tarjetasDeCreditoProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Deja sitio al teclado: sin esto el campo del importe queda tapado justo al escribir.
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formulario,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editando ? 'Editar compra' : 'Nueva compra',
                style: tema.textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _monto,
                autofocus: !_editando,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                // Se admiten coma y punto: un importe con centavos se teclea «192.729,03» y
                // hay teclados que solo ofrecen el punto.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                style: tema.textTheme.headlineMedium,
                decoration: const InputDecoration(
                  prefixText: r'$ ',
                  labelText: 'Cuánto',
                  hintText: '11.500 o 192.729,03',
                ),
                validator: (valor) {
                  final monto = Dinero.interpretar(valor ?? '');
                  if (monto == null || monto <= 0) return 'Escribe el importe';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descripcion,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Qué fue',
                  hintText: 'Chocorramo, gaseosa, taxi…',
                ),
                validator: (valor) => (valor ?? '').trim().isEmpty
                    ? 'Escribe qué compraste'
                    : null,
              ),

              if (widget.sugerencias.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final sugerencia in widget.sugerencias.take(6))
                      ActionChip(
                        label: Text(sugerencia),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _descripcion.text = sugerencia;
                        }),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              _Etiqueta('Categoría'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final categoria in CategoriaGasto.deCompras)
                    ChoiceChip(
                      label: Text(categoria.etiqueta),
                      selected: _categoria == categoria,
                      onSelected: (_) => setState(() => _categoria = categoria),
                    ),
                ],
              ),

              const SizedBox(height: 20),
              _Etiqueta('Con qué se pagó'),
              const SizedBox(height: 8),
              SegmentedButton<MedioPago>(
                segments: const [
                  ButtonSegment(
                    value: MedioPago.efectivo,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Efectivo'),
                  ),
                  ButtonSegment(
                    value: MedioPago.debito,
                    icon: Icon(Icons.account_balance_outlined),
                    label: Text('Débito'),
                  ),
                  ButtonSegment(
                    value: MedioPago.credito,
                    icon: Icon(Icons.credit_card),
                    label: Text('Crédito'),
                  ),
                ],
                selected: {_medio},
                onSelectionChanged: (seleccion) => setState(() {
                  _medio = seleccion.first;
                  if (_medio == MedioPago.credito) {
                    _tarjetaId ??= tarjetas.isEmpty ? null : tarjetas.first.id;
                  }
                }),
              ),

              if (_medio == MedioPago.credito) ...[
                const SizedBox(height: 16),
                if (tarjetas.isEmpty)
                  _Aviso(
                    icono: Icons.credit_card_off_outlined,
                    texto:
                        'No tienes tarjetas de crédito registradas. '
                        'Añade una desde Gastos diarios para poder usar el crédito.',
                    color: tema.colorScheme.error,
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _tarjetaId,
                    decoration: const InputDecoration(labelText: 'Tarjeta'),
                    items: [
                      for (final tarjeta in tarjetas)
                        DropdownMenuItem(
                          value: tarjeta.id,
                          child: Text(tarjeta.nombre),
                        ),
                    ],
                    onChanged: (id) => setState(() => _tarjetaId = id),
                  ),
                  const SizedBox(height: 12),
                  _AvisoDeVencimiento(
                    tarjeta: tarjetas.firstWhere(
                      (t) => t.id == _tarjetaId,
                      orElse: () => tarjetas.first,
                    ),
                    fecha: _fecha,
                  ),
                ],
              ],

              const SizedBox(height: 20),
              _SelectorFecha(
                fecha: _fecha,
                periodo: widget.periodo,
                alCambiar: (fecha) => setState(() => _fecha = fecha),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmar,
                      child: Text(_editando ? 'Guardar' : 'Apuntar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmar() {
    if (!_formulario.currentState!.validate()) return;

    // Sin tarjeta no se puede pagar a crédito: el servidor lo rechazaría y el mensaje llegaría
    // tarde y fuera de contexto.
    if (_medio == MedioPago.credito && _tarjetaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige con qué tarjeta se pagó')),
      );
      return;
    }

    Navigator.pop(
      context,
      DatosCompra(
        descripcion: _descripcion.text.trim(),
        monto: Dinero.interpretar(_monto.text)!,
        categoria: _categoria,
        fecha: _fecha,
        medio: _medio,
        // La tarjeta se conserva también con débito. No hace falta para calcular nada, pero es
        // el dato que dice de qué cuenta salió el dinero, y tirarlo empobrecía la compra.
        tarjetaId: _tarjetaId,
      ),
    );
  }
}

/// Avisa de en qué fecha se pagará lo que se está comprando a crédito.
///
/// Es el dato que se pierde de vista al pagar con el teléfono: comprar el 14 o el 16 cambia el
/// mes del que sale el dinero.
class _AvisoDeVencimiento extends StatelessWidget {
  const _AvisoDeVencimiento({required this.tarjeta, required this.fecha});

  final Tarjeta tarjeta;
  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final vencimiento = tarjeta.vencimientoDe(fecha);
    if (vencimiento == null) return const SizedBox.shrink();

    return _Aviso(
      icono: Icons.event_outlined,
      texto: 'Se paga el ${Formato.fecha(vencimiento)}',
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, required this.color});

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorFecha extends StatelessWidget {
  const _SelectorFecha({
    required this.fecha,
    required this.periodo,
    required this.alCambiar,
  });

  final DateTime fecha;
  final DateTime periodo;
  final void Function(DateTime) alCambiar;

  @override
  Widget build(BuildContext context) {
    // Se abre desde el primer día del mes anterior: el mes presupuestal no coincide con el del
    // calendario y las compras de finales del mes pasado se imputan a este.
    final primero = DateTime(periodo.year, periodo.month - 1, 1);
    // El día cero del mes siguiente es el último de este, sin tener que saber cuántos tiene.
    final ultimo = DateTime(periodo.year, periodo.month + 1, 0);

    return OutlinedButton.icon(
      onPressed: () async {
        final elegida = await showDatePicker(
          context: context,
          initialDate: fecha,
          firstDate: primero,
          lastDate: ultimo,
          helpText: 'Día de la compra',
        );
        if (elegida != null) alCambiar(elegida);
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        // Se avisa cuando la compra es de otro mes: es correcto, pero conviene verlo.
        fecha.month == periodo.month && fecha.year == periodo.year
            ? Formato.fecha(fecha)
            : '${Formato.fecha(fecha)}  ·  se imputa a '
                  '${Formato.mesYAnio(periodo).toLowerCase()}',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
