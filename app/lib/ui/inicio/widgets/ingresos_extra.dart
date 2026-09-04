import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dinero.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../datos/cliente_api.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/mes.dart';

/// Lo que entra durante el mes aparte del sueldo.
///
/// El sueldo se pone una vez y no se toca; esto es lo que aparece sobre la marcha: una prima, un
/// trabajo suelto, lo que devuelve alguien de una compra compartida. Sin un sitio donde apuntarlo
/// había que inflar el sueldo del mes, y entonces el bloque dejaba de coincidir con la nómina y
/// no había forma de saber de dónde salía la diferencia.
class IngresosExtra extends ConsumerWidget {
  const IngresosExtra({required this.datos, super.key});

  final DatosMes datos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final cerrado = datos.resumen.cerrado;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ingresos extra',
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (datos.ingresos.isNotEmpty)
                  Text(
                    Formato.dinero(
                      datos.extrasCobrados + datos.extrasPendientes,
                    ),
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Tema.positivo,
                    ),
                  ),
              ],
            ),

            if (datos.ingresos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aquí va lo que entre aparte del sueldo, para no tener que inflarlo.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 4),
              for (final ingreso in datos.ingresos)
                _Fila(ingreso: ingreso, bloqueado: cerrado),
              if (datos.extrasPendientes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${Formato.dinero(datos.extrasPendientes)} sin cobrar todavía: '
                    'cuentan para el cierre del mes, no para el disponible de hoy.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: cerrado ? null : () => _anadir(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Apuntar un ingreso'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _anadir(BuildContext context, WidgetRef ref) async {
    final datos = await showModalBottomSheet<_DatosIngreso>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Formulario(periodo: ref.read(periodoProvider)),
    );
    if (datos == null) return;

    try {
      await ref
          .read(mesProvider.notifier)
          .crearIngresoExtra(
            concepto: datos.concepto,
            monto: datos.monto,
            fecha: datos.fecha,
            recibido: datos.recibido,
          );
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.ingreso, required this.bloqueado});

  final IngresoExtra ingreso;
  final bool bloqueado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Dismissible(
      key: ValueKey(ingreso.id),
      direction: bloqueado
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Tema.negativo.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: Tema.negativo),
      ),
      confirmDismiss: (_) async {
        await ref.read(mesProvider.notifier).eliminarIngresoExtra(ingreso.id);
        return false;
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        // Cobrado o no es lo único que cambia el cálculo, así que se alterna con un toque.
        leading: IconButton(
          tooltip: ingreso.recibido ? 'Ya cobrado' : 'Aún sin cobrar',
          onPressed: bloqueado
              ? null
              : () => ref
                    .read(mesProvider.notifier)
                    .marcarIngresoRecibido(ingreso.id, !ingreso.recibido),
          icon: Icon(
            ingreso.recibido
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: ingreso.recibido
                ? Tema.positivo
                : tema.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(ingreso.concepto),
        subtitle: Text(
          ingreso.recibido
              ? Formato.fechaCorta(ingreso.fecha)
              : '${Formato.fechaCorta(ingreso.fecha)} · sin cobrar',
          style: tema.textTheme.bodySmall,
        ),
        trailing: Text(
          Formato.dinero(ingreso.monto),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ingreso.recibido ? Tema.positivo : null,
          ),
        ),
      ),
    );
  }
}

class _DatosIngreso {
  const _DatosIngreso(this.concepto, this.monto, this.fecha, this.recibido);

  final String concepto;
  final double monto;
  final DateTime fecha;
  final bool recibido;
}

class _Formulario extends StatefulWidget {
  const _Formulario({required this.periodo});

  final DateTime periodo;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _formulario = GlobalKey<FormState>();
  final _concepto = TextEditingController();
  final _monto = TextEditingController();

  late DateTime _fecha = _hoyDentroDelMes();
  bool _recibido = true;

  /// Hoy si el mes en pantalla es el de hoy; si no, el día uno de ese mes.
  DateTime _hoyDentroDelMes() {
    final hoy = DateTime.now();
    if (hoy.year == widget.periodo.year && hoy.month == widget.periodo.month) {
      return DateTime(hoy.year, hoy.month, hoy.day);
    }
    return DateTime(widget.periodo.year, widget.periodo.month);
  }

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
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
                'Ingreso extra',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _concepto,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Concepto',
                  hintText: 'Prima, trabajo suelto, me devolvieron…',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un concepto'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _monto,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [FormatoDeImporte()],
                decoration: const InputDecoration(
                  labelText: 'Cuánto',
                  prefixText: r'$ ',
                ),
                validator: (v) {
                  final valor = Dinero.interpretar(v ?? '');
                  if (valor == null || valor <= 0) {
                    return 'Escribe un monto mayor que cero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Fecha'),
                trailing: Text(
                  Formato.fechaCorta(_fecha),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: _elegirFecha,
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _recibido,
                onChanged: (v) => setState(() => _recibido = v),
                title: const Text('Ya lo cobré'),
                subtitle: Text(
                  _recibido
                      ? 'Sube el disponible de hoy'
                      : 'Solo cuenta para el cierre del mes, hasta que lo cobres',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: () {
                  if (!_formulario.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _DatosIngreso(
                      _concepto.text.trim(),
                      Dinero.interpretar(_monto.text)!,
                      _fecha,
                      _recibido,
                    ),
                  );
                },
                child: const Text('Apuntar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _elegirFecha() async {
    // El mes en pantalla y el del calendario no siempre coinciden, así que se deja elegir con
    // holgura alrededor: quien cobra el 28 apunta en septiembre cosas fechadas en agosto.
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(widget.periodo.year, widget.periodo.month - 1),
      lastDate: DateTime(widget.periodo.year, widget.periodo.month + 1, 0),
      locale: const Locale('es', 'CO'),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }
}
