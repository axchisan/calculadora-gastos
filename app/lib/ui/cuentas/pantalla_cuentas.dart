import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dinero.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/cuentas_y_sueldo.dart';
import '../../estado/cuentas.dart';
import '../../estado/mes.dart';

/// El saldo real de cada banco, billetera y del efectivo, comparado con lo que dice la app.
///
/// El disponible del mes sale de lo que se registra. Si alguien olvida apuntar un gasto, la
/// app sigue creyendo que ese dinero está ahí. Anotar de vez en cuando lo que muestra cada banco
/// y ver la diferencia es la forma de descubrirlo a tiempo.
class PantallaCuentas extends ConsumerWidget {
  const PantallaCuentas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentas = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis cuentas')),
      body: cuentas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ErrorApi
                      ? error.mensaje
                      : 'No se pudieron cargar las cuentas',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(cuentasProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (lista) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cuentasProvider);
            await ref.read(mesProvider.notifier).refrescar();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const TarjetaCuadre(),
              const SizedBox(height: 20),
              Text(
                'Toca una cuenta para anotar el saldo que te muestra hoy.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Aún no hay cuentas. Añade tus bancos y el efectivo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final cuenta in lista) _FilaCuenta(cuenta: cuenta),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevaCuenta(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Cuenta'),
      ),
    );
  }

  Future<void> _nuevaCuenta(BuildContext context, WidgetRef ref) async {
    final nombre = TextEditingController();
    final saldo = TextEditingController();
    var tipo = TipoCuenta.banco;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setState) => AlertDialog(
          title: const Text('Nueva cuenta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TipoCuenta>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in TipoCuenta.values)
                    DropdownMenuItem(value: t, child: Text(t.etiqueta)),
                ],
                onChanged: (t) => setState(() => tipo = t ?? tipo),
              ),
              const SizedBox(height: 12),
              _CampoImporte(controlador: saldo, etiqueta: 'Saldo de hoy'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (confirmado != true || nombre.text.trim().isEmpty) return;
    if (!context.mounted) return;

    await _ejecutar(context, ref, () async {
      await ref
          .read(repositorioCuentasProvider)
          .crear(
            nombre: nombre.text.trim(),
            tipo: tipo,
            saldo: Dinero.interpretar(saldo.text) ?? 0,
          );
    });
  }
}

/// Compara el dinero real con el disponible que calcula la app para el mes en pantalla.
class TarjetaCuadre extends ConsumerWidget {
  const TarjetaCuadre({super.key, this.alTocar});

  /// Si se indica, la tarjeta es tocable (para usarla como acceso desde el inicio).
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final real = ref.watch(dineroRealProvider);
    final mes = ref.watch(mesProvider);
    final tema = Theme.of(context);

    // Solo tiene sentido comparar con el mes en curso: el disponible de un mes pasado o futuro
    // no es el dinero de hoy. El mes presupuestal va del 28 al 27.
    final hoy = DateTime.now();
    final mesEnCurso = hoy.day >= 28
        ? DateTime(hoy.year, hoy.month + 1)
        : DateTime(hoy.year, hoy.month);
    final periodo = ref.watch(periodoProvider);
    final esMesEnCurso =
        periodo.year == mesEnCurso.year && periodo.month == mesEnCurso.month;

    final disponible = esMesEnCurso
        ? mes.valueOrNull?.resumen.disponibleHoy
        : null;
    final total = real.valueOrNull;

    Widget? diferencia;
    if (total != null && disponible != null) {
      final dif = total - disponible;
      final cuadra = dif.abs() < 1;
      final color = cuadra ? Tema.positivo : Tema.pendiente;
      final texto = cuadra
          ? 'Cuadra con la app'
          : dif < 0
          ? 'Faltan ${Formato.dinero(-dif)} por registrar como gasto'
          : 'Hay ${Formato.dinero(dif)} que la app no sabe de dónde salieron';
      diferencia = Row(
        children: [
          Icon(
            cuadra ? Icons.check_circle : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: tema.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Dinero real hoy', style: tema.textTheme.titleSmall),
                  const Spacer(),
                  if (alTocar != null) const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                total == null ? '…' : Formato.dinero(total),
                style: tema.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (disponible != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Según la app: ${Formato.dinero(disponible)} disponibles',
                  style: tema.textTheme.bodySmall,
                ),
              ],
              if (diferencia != null) ...[
                const SizedBox(height: 10),
                diferencia,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaCuenta extends ConsumerWidget {
  const _FilaCuenta({required this.cuenta});

  final Cuenta cuenta;

  IconData get _icono => switch (cuenta.tipo) {
    TipoCuenta.banco => Icons.account_balance_outlined,
    TipoCuenta.billetera => Icons.phone_android,
    TipoCuenta.efectivo => Icons.payments_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dias = cuenta.diasSinActualizar;
    final antiguedad = dias == 0
        ? 'Actualizado hoy'
        : dias == 1
        ? 'Actualizado ayer'
        : 'Hace $dias días · ${Formato.fechaCorta(cuenta.saldoAl)}';

    return Opacity(
      opacity: cuenta.activa ? 1 : 0.5,
      child: Card(
        child: ListTile(
          leading: Icon(_icono),
          title: Text(cuenta.nombre),
          subtitle: Text(
            cuenta.activa ? antiguedad : 'Archivada',
            style: dias > 7 && cuenta.activa
                ? const TextStyle(color: Tema.pendiente)
                : null,
          ),
          trailing: Text(
            Formato.dinero(cuenta.saldo),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          onTap: () => _anotarSaldo(context, ref),
          onLongPress: () => _opciones(context, ref),
        ),
      ),
    );
  }

  Future<void> _anotarSaldo(BuildContext context, WidgetRef ref) async {
    final campo = TextEditingController(text: Dinero.paraEditar(cuenta.saldo));
    final valor = await showDialog<double>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(cuenta.nombre),
        content: _CampoImporte(
          controlador: campo,
          etiqueta: 'Saldo que ves hoy',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(contexto, Dinero.interpretar(campo.text) ?? 0),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (valor == null || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref
          .read(repositorioCuentasProvider)
          .actualizar(cuenta.id, saldo: valor),
    );
  }

  Future<void> _opciones(BuildContext context, WidgetRef ref) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                cuenta.activa ? Icons.archive_outlined : Icons.unarchive,
              ),
              title: Text(cuenta.activa ? 'Archivar' : 'Reactivar'),
              subtitle: cuenta.activa
                  ? const Text('Deja de sumar en el dinero real')
                  : null,
              onTap: () => Navigator.pop(contexto, 'archivar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Tema.negativo),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(contexto, 'eliminar'),
            ),
          ],
        ),
      ),
    );
    if (opcion == null || !context.mounted) return;
    final repo = ref.read(repositorioCuentasProvider);
    await _ejecutar(
      context,
      ref,
      () => opcion == 'archivar'
          ? repo.actualizar(cuenta.id, activa: !cuenta.activa)
          : repo.eliminar(cuenta.id),
    );
  }
}

class _CampoImporte extends StatelessWidget {
  const _CampoImporte({
    required this.controlador,
    required this.etiqueta,
    this.autofocus = false,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const <TextInputFormatter>[FormatoDeImporte()],
      decoration: InputDecoration(labelText: etiqueta, prefixText: r'$ '),
    );
  }
}

Future<void> _ejecutar(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() accion,
) async {
  try {
    await accion();
    ref.invalidate(cuentasProvider);
  } on ErrorApi catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.mensaje)));
  }
}
