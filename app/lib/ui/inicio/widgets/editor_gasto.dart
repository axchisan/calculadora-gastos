import 'package:flutter/material.dart';

import '../../../core/formato.dart';
import '../../../dominio/modelos.dart';

/// Cambios sobre un gasto del mes.
class DatosGastoEditado {
  const DatosGastoEditado({
    required this.nombre,
    required this.categoria,
    required this.monto,
    this.diaVencimiento,
  });

  final String nombre;
  final CategoriaGasto categoria;
  final double monto;
  final int? diaVencimiento;
}

/// Edita un gasto concreto del mes.
///
/// Cambia solo este mes: el importe habitual vive en la plantilla de gastos fijos, y ajustarlo
/// aquí no la toca. Es lo que permite que el celular salga más caro en agosto sin que eso
/// altere lo que se espera pagar el resto del año.
class EditorGasto extends StatefulWidget {
  const EditorGasto({required this.gasto, super.key});

  final Gasto gasto;

  static Future<DatosGastoEditado?> abrir(BuildContext context, Gasto gasto) =>
      showModalBottomSheet<DatosGastoEditado>(
        context: context,
        isScrollControlled: true,
        builder: (_) => EditorGasto(gasto: gasto),
      );

  @override
  State<EditorGasto> createState() => _EditorGastoState();
}

class _EditorGastoState extends State<EditorGasto> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _monto;
  late final TextEditingController _dia;
  late CategoriaGasto _categoria;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.gasto.nombre);
    _monto = TextEditingController(text: widget.gasto.monto.round().toString());
    _dia = TextEditingController(
      text: widget.gasto.diaVencimiento?.toString() ?? '',
    );
    _categoria = widget.gasto.categoria;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    _dia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vieneDePlantilla = widget.gasto.origen == OrigenGasto.plantilla;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar gasto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Concepto'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un concepto'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _monto,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto de este mes',
                  prefixText: r'$ ',
                  helperText: vieneDePlantilla
                      ? 'Solo cambia este mes; el habitual sigue en tus gastos fijos'
                      : null,
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final valor = double.tryParse((v ?? '').replaceAll('.', ''));
                  if (valor == null || valor < 0) {
                    return 'Escribe un monto válido';
                  }
                  if (valor < widget.gasto.montoPagado) {
                    // Bajarlo por debajo de lo abonado dejaría un pago superior al gasto.
                    return 'Ya has pagado '
                        '${Formato.dinero(widget.gasto.montoPagado)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<CategoriaGasto>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: CategoriaGasto.values
                    .map(
                      (c) =>
                          DropdownMenuItem(value: c, child: Text(c.etiqueta)),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _categoria = v ?? CategoriaGasto.otro),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dia,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Día de vencimiento (opcional)',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final dia = int.tryParse(v);
                  if (dia == null || dia < 1 || dia > 31) {
                    return 'Debe estar entre 1 y 31';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: () {
                  if (!_formulario.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    DatosGastoEditado(
                      nombre: _nombre.text.trim(),
                      categoria: _categoria,
                      monto: double.parse(_monto.text.replaceAll('.', '')),
                      diaVencimiento: int.tryParse(_dia.text),
                    ),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
