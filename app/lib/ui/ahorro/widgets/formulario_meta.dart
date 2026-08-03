import 'package:flutter/material.dart';

import '../../../dominio/modelos.dart';

/// Datos recogidos para crear una meta de ahorro.
class DatosNuevaMeta {
  const DatosNuevaMeta({
    required this.nombre,
    required this.tipo,
    required this.valor,
    this.objetivo,
    this.prioridad,
  });

  final String nombre;
  final TipoAsignacion tipo;
  final double valor;
  final double? objetivo;
  final int? prioridad;
}

class FormularioMeta extends StatefulWidget {
  const FormularioMeta({super.key});

  @override
  State<FormularioMeta> createState() => _FormularioMetaState();
}

class _FormularioMetaState extends State<FormularioMeta> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _valor = TextEditingController();
  final _objetivo = TextEditingController();

  TipoAsignacion _tipo = TipoAsignacion.porcentajeSobrante;

  bool get _esPorcentaje => _tipo != TipoAsignacion.montoFijo;

  @override
  void dispose() {
    _nombre.dispose();
    _valor.dispose();
    _objetivo.dispose();
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
                'Nueva meta de ahorro',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Fondo de emergencia, viaje…',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un nombre'
                    : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<TipoAsignacion>(
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'De dónde sale el dinero',
                ),
                items: TipoAsignacion.values
                    .map(
                      (t) =>
                          DropdownMenuItem(value: t, child: Text(t.etiqueta)),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _tipo = v ?? TipoAsignacion.montoFijo),
              ),
              const SizedBox(height: 8),
              Text(
                _explicacion(_tipo),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _valor,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _esPorcentaje ? 'Porcentaje' : 'Cantidad mensual',
                  prefixText: _esPorcentaje ? null : r'$ ',
                  suffixText: _esPorcentaje ? '%' : null,
                ),
                validator: (v) {
                  final valor = double.tryParse(
                    (v ?? '').replaceAll('.', '').replaceAll(',', '.'),
                  );
                  if (valor == null || valor <= 0) {
                    return 'Escribe un valor mayor que cero';
                  }
                  if (_esPorcentaje && valor > 100) {
                    return 'No puede pasar del 100%';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _objetivo,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(
                  labelText: 'Objetivo (opcional)',
                  prefixText: r'$ ',
                  helperText: 'Al alcanzarlo, la meta deja de reclamar dinero',
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: () {
                  if (!_formulario.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    DatosNuevaMeta(
                      nombre: _nombre.text.trim(),
                      tipo: _tipo,
                      valor: double.parse(
                        _valor.text.replaceAll('.', '').replaceAll(',', '.'),
                      ),
                      objetivo: double.tryParse(
                        _objetivo.text.replaceAll('.', ''),
                      ),
                    ),
                  );
                },
                child: const Text('Crear meta'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _explicacion(TipoAsignacion tipo) => switch (tipo) {
    TipoAsignacion.montoFijo =>
      'Siempre la misma cantidad, pase lo que pase con el mes.',
    TipoAsignacion.porcentajeIngreso =>
      'Un porcentaje del sueldo, así sube o baja con lo que ingreses.',
    TipoAsignacion.porcentajeSobrante =>
      'Un porcentaje de lo que quede tras gastos y deudas. Si hay varias metas de este '
          'tipo, cada una calcula sobre lo que dejó la anterior.',
  };
}
