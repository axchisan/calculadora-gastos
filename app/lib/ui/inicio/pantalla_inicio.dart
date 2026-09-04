import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/dinero.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../datos/repositorio_meses.dart';
import '../../dominio/modelos.dart';
import '../../estado/mes.dart';
import '../../estado/modo_vista.dart';
import 'widgets/editor_ingreso.dart';
import 'widgets/ingresos_extra.dart';
import 'widgets/lista_gastos.dart';
import 'widgets/tarjeta_saldo.dart';

/// Pantalla principal: el estado del mes en curso.
class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoProvider);
    final datos = ref.watch(mesProvider);

    return Scaffold(
      appBar: AppBar(
        // El título es un botón: con solo las flechas, plantarse en un mes lejano costaba
        // muchos toques, y volver al de hoy tras curiosear el año que viene, otros tantos.
        title: InkWell(
          onTap: () => _elegirMes(context, ref),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Formato.mesYAnio(periodo)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 22),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mes anterior',
            onPressed: () => _moverMes(ref, -1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Mes siguiente',
            onPressed: () => _moverMes(ref, 1),
          ),
          PopupMenuButton<String>(
            onSelected: (opcion) => _menu(context, ref, opcion, datos),
            itemBuilder: (_) {
              final cerrado = datos.valueOrNull?.resumen.cerrado ?? false;
              return [
                const PopupMenuItem(
                  value: 'aplicar',
                  child: Text('Traer mis gastos fijos'),
                ),
                const PopupMenuItem(
                  value: 'plantillas',
                  child: Text('Configurar gastos fijos'),
                ),
                PopupMenuItem(
                  value: cerrado ? 'reabrir' : 'cerrar',
                  child: Text(cerrado ? 'Reabrir el mes' : 'Cerrar el mes'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'recargar', child: Text('Recargar')),
                const PopupMenuItem(value: 'cuenta', child: Text('Mi cuenta')),
              ];
            },
          ),
        ],
      ),
      body: datos.when(
        loading: () => const _Cargando(),
        error: (error, _) => _Error(
          mensaje: error is ErrorApi
              ? error.mensaje
              : 'No se pudo cargar el mes',
          alReintentar: () => ref.read(mesProvider.notifier).cargar(),
        ),
        data: (d) => _Contenido(
          datos: d,
          alEditarIngreso: () =>
              _editarIngreso(context, ref, d.resumen.ingresoBase),
        ),
      ),
      floatingActionButton: datos.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _nuevoGasto(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Gasto'),
            )
          : null,
    );
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    String opcion,
    AsyncValue<DatosMes> datos,
  ) async {
    switch (opcion) {
      case 'cuenta':
        context.push(Rutas.cuenta);
      case 'plantillas':
        context.push(Rutas.plantillas);
      case 'aplicar':
        await _aplicarPlantillas(context, ref);
      case 'recargar':
        await ref.read(mesProvider.notifier).cargar();
      case 'cerrar':
        await _cerrarMes(context, ref);
      case 'reabrir':
        await _ejecutar(
          context,
          () => ref.read(mesProvider.notifier).reabrir(),
        );
    }
  }

  /// Añade al mes los gastos fijos que falten.
  ///
  /// Hace falta porque las plantillas se copian al crear el mes: una configurada después no
  /// aparece sola en los meses que ya existían.
  Future<void> _aplicarPlantillas(BuildContext context, WidgetRef ref) async {
    try {
      final anadidos = await ref.read(mesProvider.notifier).aplicarPlantillas();
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            anadidos == 0
                ? 'Este mes ya tiene todos tus gastos fijos'
                : anadidos == 1
                ? 'Se añadió 1 gasto fijo'
                : 'Se añadieron $anadidos gastos fijos',
          ),
        ),
      );
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _cerrarMes(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Cerrar el mes'),
        content: const Text(
          'El mes queda como registro histórico y deja de admitir cambios. Puedes reabrirlo '
          'cuando quieras desde el mismo menú.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (!(confirmado ?? false) || !context.mounted) return;
    await _ejecutar(context, () => ref.read(mesProvider.notifier).cerrar());
  }

  Future<void> _editarIngreso(
    BuildContext context,
    WidgetRef ref,
    double actual,
  ) async {
    final nuevo = await EditorIngreso.abrir(context, actual);
    if (nuevo == null || !context.mounted) return;
    await _ejecutar(
      context,
      () => ref.read(mesProvider.notifier).actualizarIngreso(nuevo),
    );
  }

  Future<void> _ejecutar(
    BuildContext context,
    Future<void> Function() accion,
  ) async {
    try {
      await accion();
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  /// Salta a cualquier mes, o vuelve al de hoy.
  ///
  /// Hace falta porque el mes presupuestal y el del calendario no coinciden: se puede estar
  /// trabajando en septiembre mientras el teléfono dice 31 de agosto.
  Future<void> _elegirMes(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(periodoProvider);
    final hoy = DateTime.now();

    final elegido = await showDialog<DateTime>(
      context: context,
      builder: (contexto) => _SelectorDeMes(actual: actual, hoy: hoy),
    );
    if (elegido != null) {
      ref.read(periodoProvider.notifier).state = elegido;
    }
  }

  void _moverMes(WidgetRef ref, int desplazamiento) {
    final actual = ref.read(periodoProvider);
    ref.read(periodoProvider.notifier).state = DateTime(
      actual.year,
      actual.month + desplazamiento,
    );
  }

  Future<void> _nuevoGasto(BuildContext context, WidgetRef ref) async {
    final resultado = await showModalBottomSheet<_NuevoGasto>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FormularioGasto(),
    );
    if (resultado == null) return;

    try {
      await ref
          .read(mesProvider.notifier)
          .crearGasto(
            nombre: resultado.nombre,
            categoria: resultado.categoria,
            monto: resultado.monto,
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

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.datos, required this.alEditarIngreso});

  final DatosMes datos;
  final VoidCallback alEditarIngreso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchoMaximo = Pantalla.esEscritorio(context)
        ? 760.0
        : double.infinity;

    return RefreshIndicator(
      onRefresh: () => ref.read(mesProvider.notifier).refrescar(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (RepositorioMeses.ultimaLecturaDesdeCache) ...[
                const _AvisoSinConexion(),
                const SizedBox(height: 12),
              ],
              TarjetaSaldo(
                resumen: datos.resumen,
                modo: ref.watch(modoVistaProvider),
                // Un mes cerrado no admite cambios.
                alEditarIngreso: datos.resumen.cerrado ? null : alEditarIngreso,
                alAlternarModo: () =>
                    ref.read(modoVistaProvider.notifier).alternar(),
              ),
              const SizedBox(height: 20),
              IngresosExtra(datos: datos),
              const SizedBox(height: 20),
              ListaGastos(datos: datos),
            ],
          ),
        ),
      ),
    );
  }
}

/// Se muestra cuando lo que hay en pantalla proviene del caché por falta de conexión.
class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Tema.pendiente.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: Tema.pendiente),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sin conexión. Ves los últimos datos guardados; los cambios no se guardarán '
              'hasta recuperarla.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          // La primera petición del día puede coincidir con el arranque en frío del servidor.
          Text('Preparando tu mes…'),
        ],
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

// --- formulario de gasto puntual ---

class _NuevoGasto {
  const _NuevoGasto(this.nombre, this.categoria, this.monto);

  final String nombre;
  final CategoriaGasto categoria;
  final double monto;
}

class _FormularioGasto extends StatefulWidget {
  const _FormularioGasto();

  @override
  State<_FormularioGasto> createState() => _FormularioGastoState();
}

class _FormularioGastoState extends State<_FormularioGasto> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  CategoriaGasto _categoria = CategoriaGasto.otro;

  @override
  void dispose() {
    _nombre.dispose();
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
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nuevo gasto', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              autofocus: true,
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
                labelText: 'Monto',
                prefixText: r'$ ',
              ),
              validator: (v) {
                final valor = Dinero.interpretar(v ?? '');
                if (valor == null) return 'Escribe un monto válido';
                if (valor < 0) return 'No puede ser negativo';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CategoriaGasto>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: CategoriaGasto.values
                  .map(
                    (c) => DropdownMenuItem(value: c, child: Text(c.etiqueta)),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _categoria = v ?? CategoriaGasto.otro),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!_formulario.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _NuevoGasto(
                    _nombre.text.trim(),
                    _categoria,
                    Dinero.interpretar(_monto.text)!,
                  ),
                );
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elige un mes de los que tienen sentido: unos atrás y unos adelante.
///
/// Se limita el rango a propósito. Un selector de fecha completo obligaría a navegar por días
/// que aquí no significan nada, y de todas formas nadie presupuesta a cinco años vista.
class _SelectorDeMes extends StatefulWidget {
  const _SelectorDeMes({required this.actual, required this.hoy});

  final DateTime actual;
  final DateTime hoy;

  @override
  State<_SelectorDeMes> createState() => _SelectorDeMesState();
}

class _SelectorDeMesState extends State<_SelectorDeMes> {
  late int _anio = widget.actual.year;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esteMes = DateTime(widget.hoy.year, widget.hoy.month);

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _anio--),
          ),
          Expanded(
            child: Text(
              '$_anio',
              textAlign: TextAlign.center,
              style: tema.textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _anio++),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 2.1,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var mes = 1; mes <= 12; mes++)
              _Mes(
                periodo: DateTime(_anio, mes),
                seleccionado:
                    _anio == widget.actual.year && mes == widget.actual.month,
                esElDeHoy: DateTime(_anio, mes) == esteMes,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, esteMes),
          child: const Text('Ir al mes de hoy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _Mes extends StatelessWidget {
  const _Mes({
    required this.periodo,
    required this.seleccionado,
    required this.esElDeHoy,
  });

  final DateTime periodo;
  final bool seleccionado;
  final bool esElDeHoy;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Material(
      color: seleccionado
          ? tema.colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pop(context, periodo),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            // El mes del calendario se marca con un borde, para poder distinguirlo del que se
            // está viendo cuando no son el mismo.
            border: esElDeHoy && !seleccionado
                ? Border.all(color: tema.colorScheme.outline)
                : null,
          ),
          child: Text(
            Formato.nombreDeMes(periodo.month),
            style: tema.textTheme.bodyMedium?.copyWith(
              fontWeight: seleccionado ? FontWeight.w700 : null,
              color: seleccionado ? tema.colorScheme.onPrimaryContainer : null,
            ),
          ),
        ),
      ),
    );
  }
}
