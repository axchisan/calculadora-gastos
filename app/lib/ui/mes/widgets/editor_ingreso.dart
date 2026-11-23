import 'package:flutter/material.dart';

import '../../../core/dinero.dart';
import '../../../core/formato.dart';

/// Diálogo para ajustar el sueldo del mes.
///
/// El sueldo se hereda del mes anterior al crear uno nuevo, pero puede variar: primas, cambios
/// de contrato o meses con horas extra. Editarlo aquí recalcula el disponible al instante.
class EditorIngreso extends StatefulWidget {
  const EditorIngreso({required this.actual, super.key});

  final double actual;

  /// Abre el diálogo y devuelve el nuevo importe, o null si se canceló.
  static Future<double?> abrir(BuildContext context, double actual) =>
      showDialog<double>(
        context: context,
        builder: (_) => EditorIngreso(actual: actual),
      );

  @override
  State<EditorIngreso> createState() => _EditorIngresoState();
}

class _EditorIngresoState extends State<EditorIngreso> {
  late final TextEditingController _campo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _campo = TextEditingController(
      text: widget.actual == 0 ? '' : Dinero.paraEditar(widget.actual),
    );
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _guardar() {
    final valor = Dinero.interpretar(_campo.text);
    if (valor == null || valor < 0) {
      setState(() => _error = 'Escribe un monto válido');
      return;
    }
    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sueldo del mes'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _campo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoDeImporte()],
            onSubmitted: (_) => _guardar(),
            decoration: InputDecoration(
              prefixText: r'$ ',
              errorText: _error,
              helperText: 'Solo afecta a este mes',
            ),
          ),
          if (widget.actual > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Ahora: ${Formato.dinero(widget.actual)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
