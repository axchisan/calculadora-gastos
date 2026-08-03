import 'package:flutter/material.dart';

import '../../../dominio/modelos.dart';

/// Datos recogidos para crear una deuda.
class DatosNuevaDeuda {
  const DatosNuevaDeuda({
    required this.acreedor,
    required this.tipo,
    required this.monto,
    this.tasaInteres,
    this.cuota,
  });

  final String acreedor;
  final TipoDeuda tipo;
  final double monto;
  final double? tasaInteres;
  final double? cuota;
}

class FormularioDeuda extends StatefulWidget {
  const FormularioDeuda({this.deuda, super.key});

  /// Deuda a editar, o nulo para crear una nueva.
  final Deuda? deuda;

  @override
  State<FormularioDeuda> createState() => _FormularioDeudaState();
}

class _FormularioDeudaState extends State<FormularioDeuda> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _acreedor;
  late final TextEditingController _monto;
  late final TextEditingController _tasa;
  late final TextEditingController _cuota;

  late TipoDeuda _tipo;

  bool get _esEdicion => widget.deuda != null;

  @override
  void initState() {
    super.initState();
    final d = widget.deuda;
    _acreedor = TextEditingController(text: d?.acreedor ?? '');
    _monto = TextEditingController(
      text: d == null ? '' : d.montoOriginal.round().toString(),
    );
    _tasa = TextEditingController(
      text: d?.tasaInteresMensual?.toString() ?? '',
    );
    _cuota = TextEditingController(
      text: d?.cuotaSugerida == null
          ? ''
          : d!.cuotaSugerida!.round().toString(),
    );
    _tipo = d?.tipo ?? TipoDeuda.tarjetaCredito;
  }

  @override
  void dispose() {
    _acreedor.dispose();
    _monto.dispose();
    _tasa.dispose();
    _cuota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                _esEdicion ? 'Editar deuda' : 'Nueva deuda',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _acreedor,
                autofocus: !_esEdicion,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: '¿A quién le debes?',
                  hintText: 'Tarjeta Bancolombia, Papá, un amigo…',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Escribe a quién' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<TipoDeuda>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: TipoDeuda.values
                    .map(
                      (t) =>
                          DropdownMenuItem(value: t, child: Text(t.etiqueta)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v ?? TipoDeuda.otro),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _monto,
                enabled: !_esEdicion,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: InputDecoration(
                  labelText: 'Cuánto debes',
                  prefixText: r'$ ',
                  helperText: _esEdicion
                      // Cambiarlo descuadraría el porcentaje pagado y los abonos ya hechos.
                      ? 'El importe original no se puede cambiar'
                      : null,
                ),
                validator: (v) {
                  if (_esEdicion) return null;
                  final valor = double.tryParse((v ?? '').replaceAll('.', ''));
                  if (valor == null || valor <= 0) {
                    return 'Escribe un monto mayor que cero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tasa,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Interés mensual (opcional)',
                  suffixText: '%',
                  helperText: 'Los préstamos familiares no suelen tenerlo',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _cuota,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cuota mensual (opcional)',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: () {
                  if (!_formulario.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    DatosNuevaDeuda(
                      acreedor: _acreedor.text.trim(),
                      tipo: _tipo,
                      monto: _esEdicion
                          ? widget.deuda!.montoOriginal
                          : double.parse(_monto.text.replaceAll('.', '')),
                      tasaInteres: double.tryParse(
                        _tasa.text.replaceAll(',', '.'),
                      ),
                      cuota: double.tryParse(_cuota.text.replaceAll('.', '')),
                    ),
                  );
                },
                child: Text(_esEdicion ? 'Guardar' : 'Añadir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
