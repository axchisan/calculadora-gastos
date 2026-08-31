import 'package:flutter/material.dart';

import '../../../core/dinero.dart';
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

  /// Lee el campo del valor según lo que represente ahora mismo.
  ///
  /// Un porcentaje no puede leerse como importe: la regla de los importes trata una sola cifra
  /// tras el separador como miles, y convertiría un `2,5 %` en un 25 %.
  double? _leerValor(String texto) =>
      _esPorcentaje ? Dinero.interpretarTasa(texto) : Dinero.interpretar(texto);

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
                onChanged: (v) => setState(() {
                  final nuevo = v ?? TipoAsignacion.montoFijo;
                  // Un 50 significa medio sobrante o cincuenta mil pesos según el tipo, así
                  // que al cambiarlo se vacía el campo: reinterpretar la cifra por dentro
                  // sería adivinar, y aquí adivinar mal cuesta dinero.
                  if ((nuevo != TipoAsignacion.montoFijo) != _esPorcentaje) {
                    _valor.clear();
                  }
                  _tipo = nuevo;
                }),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  _esPorcentaje
                      ? const FormatoDeImporte.tasa(decimalesMaximos: 2)
                      : const FormatoDeImporte(),
                ],
                decoration: InputDecoration(
                  labelText: _esPorcentaje ? 'Porcentaje' : 'Cantidad mensual',
                  prefixText: _esPorcentaje ? null : r'$ ',
                  suffixText: _esPorcentaje ? '%' : null,
                ),
                validator: (v) {
                  final valor = _leerValor(v ?? '');
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
                  decimal: true,
                ),
                inputFormatters: const [FormatoDeImporte()],
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
                      valor: _leerValor(_valor.text)!,
                      objetivo: Dinero.interpretar(_objetivo.text),
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
