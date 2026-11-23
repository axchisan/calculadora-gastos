import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../comun/deshacer.dart';
import '../comun/iconos.dart';
import '../comun/componentes.dart';

import '../../core/dinero.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/modelos.dart';
import '../../estado/plantillas.dart';

/// Gastos fijos que se copian a cada mes nuevo.
class PantallaPlantillas extends ConsumerWidget {
  const PantallaPlantillas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(plantillasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos fijos')),
      body: datos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(
          mensaje: error is ErrorApi
              ? error.mensaje
              : 'No se pudieron cargar los gastos fijos',
          alReintentar: () => ref.read(plantillasProvider.notifier).cargar(),
        ),
        data: (plantillas) => _Contenido(plantillas: plantillas),
      ),
      floatingActionButton: datos.hasValue
          ? FloatingActionButton(
              tooltip: 'Nuevo gasto fijo',
              onPressed: () => _editar(context, ref, null),
              child: const Icon(Iconos.anadir),
            )
          : null,
    );
  }

  static Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    PlantillaGasto? plantilla,
  ) async {
    final datos = await showModalBottomSheet<_DatosPlantilla>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _Formulario(plantilla: plantilla),
    );
    if (datos == null) return;

    try {
      final controlador = ref.read(plantillasProvider.notifier);
      if (plantilla == null) {
        await controlador.crear(
          nombre: datos.nombre,
          categoria: datos.categoria,
          monto: datos.monto,
          diaVencimiento: datos.diaVencimiento,
        );
      } else {
        await controlador.actualizar(
          plantilla.id,
          nombre: datos.nombre,
          categoria: datos.categoria,
          monto: datos.monto,
          diaVencimiento: datos.diaVencimiento,
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
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.plantillas});

  final List<PlantillaGasto> plantillas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plantillas.isEmpty) return const _SinPlantillas();

    final ocultos = ref.watch(ocultosProvider);
    final visibles = plantillas.sinOcultos(ocultos, (p) => p.id);
    final activas = visibles.where((p) => p.activo).toList();
    final inactivas = visibles.where((p) => !p.activo).toList();
    final total = activas.fold<double>(0, (s, p) => s + p.montoDefault);
    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 640.0
        : double.infinity;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espacio.lateral,
            Espacio.s,
            Espacio.lateral,
            96,
          ),
          children: [
            const SizedBox(height: Espacio.m),
            CifraPrincipal(etiqueta: 'Cada mes empieza con', valor: total),
            const SizedBox(height: Espacio.s),
            Text(
              'El transporte se suma aparte, calculado desde el calendario.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.colores.tinta2),
            ),
            Seccion(
              titulo: 'Tus gastos fijos',
              accion: '${activas.length}',
              child: Panel.lista(
                filas: [
                  for (final plantilla in [...activas, ...inactivas])
                    _Fila(plantilla: plantilla),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Cambiar un gasto fijo no altera los meses ya creados: subir el arriendo hoy '
                'no reescribe lo que pagaste el mes pasado.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.plantilla});

  final PlantillaGasto plantilla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _eliminar(context, ref),
      child: Opacity(
        opacity: plantilla.activo ? 1 : 0.5,
        child: Fila(
          inicio: IconoCaja(Iconos.deCategoria(plantilla.categoria)),
          titulo: plantilla.nombre,
          subtitulo: plantilla.diaVencimiento == null
              ? plantilla.categoria.etiqueta
              : '${plantilla.categoria.etiqueta} · vence el ${plantilla.diaVencimiento}',
          final_: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Importe(plantilla.montoDefault, colorear: false),
              const SizedBox(width: Espacio.xs),
              Switch(
                value: plantilla.activo,
                onChanged: (valor) => _cambiarActivo(context, ref, valor),
              ),
            ],
          ),
          etiqueta: plantilla.activo ? null : const Etiqueta('En pausa'),
          alTocar: () => PantallaPlantillas._editar(context, ref, plantilla),
        ),
      ),
    );
  }

  Future<void> _cambiarActivo(
    BuildContext context,
    WidgetRef ref,
    bool activo,
  ) async {
    try {
      await ref
          .read(plantillasProvider.notifier)
          .cambiarActivo(plantilla.id, activo);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  /// Se borra con «Deshacer» durante unos segundos, como todo en la app.
  Future<void> _eliminar(BuildContext context, WidgetRef ref) =>
      borrarConDeshacer(
        context,
        ref,
        id: plantilla.id,
        mensaje: 'Eliminaste «${plantilla.nombre}» de los gastos fijos',
        borrar: () =>
            ref.read(plantillasProvider.notifier).eliminar(plantilla.id),
      );
}

class _DatosPlantilla {
  const _DatosPlantilla({
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

class _Formulario extends StatefulWidget {
  const _Formulario({this.plantilla});

  final PlantillaGasto? plantilla;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _monto;
  late final TextEditingController _dia;
  late CategoriaGasto _categoria;

  @override
  void initState() {
    super.initState();
    final p = widget.plantilla;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _monto = TextEditingController(
      text: p == null ? '' : Dinero.paraEditar(p.montoDefault),
    );
    _dia = TextEditingController(text: p?.diaVencimiento?.toString() ?? '');
    _categoria = p?.categoria ?? CategoriaGasto.otro;
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
                widget.plantilla == null
                    ? 'Nuevo gasto fijo'
                    : 'Editar gasto fijo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombre,
                autofocus: widget.plantilla == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Concepto'),
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
                  labelText: 'Monto habitual',
                  prefixText: r'$ ',
                  helperText: 'Se puede ajustar mes a mes',
                ),
                validator: (v) {
                  final valor = Dinero.interpretar(v ?? '');
                  if (valor == null || valor < 0) {
                    return 'Escribe un monto válido';
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  labelText: 'Día de vencimiento (opcional)',
                  helperText: 'Del 1 al 31, para ordenar lo que vence antes',
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
                    _DatosPlantilla(
                      nombre: _nombre.text.trim(),
                      categoria: _categoria,
                      monto: Dinero.interpretar(_monto.text)!,
                      diaVencimiento: int.tryParse(_dia.text),
                    ),
                  );
                },
                child: Text(widget.plantilla == null ? 'Añadir' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SinPlantillas extends StatelessWidget {
  const _SinPlantillas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin gastos fijos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Añade lo que pagas todos los meses —arriendo, celular, suscripciones— y cada '
              'mes nuevo aparecerá ya montado.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Tema.pendiente,
            ),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: alReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
