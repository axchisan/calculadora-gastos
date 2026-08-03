import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/modelos.dart';
import '../../estado/mes.dart';
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
        title: Text(Formato.mesYAnio(periodo)),
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
            onSelected: (opcion) {
              if (opcion == 'cuenta') {
                context.push(Rutas.cuenta);
              }
              if (opcion == 'recargar') {
                ref.read(mesProvider.notifier).cargar();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'recargar', child: Text('Recargar')),
              PopupMenuItem(value: 'cuenta', child: Text('Mi cuenta')),
            ],
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
        data: (d) => _Contenido(datos: d),
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
  const _Contenido({required this.datos});

  final DatosMes datos;

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
              TarjetaSaldo(resumen: datos.resumen),
              const SizedBox(height: 20),
              ListaGastos(datos: datos),
            ],
          ),
        ),
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
                decimal: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: r'$ ',
              ),
              validator: (v) {
                final valor = double.tryParse((v ?? '').replaceAll('.', ''));
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
                    double.parse(_monto.text.replaceAll('.', '')),
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
