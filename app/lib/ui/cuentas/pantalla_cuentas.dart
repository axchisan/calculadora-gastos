import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dominio/inicio.dart';
import '../../estado/inicio.dart';
import '../comun/iconos.dart';
import '../comun/componentes.dart';

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
            padding: const EdgeInsets.fromLTRB(
              Espacio.lateral,
              Espacio.s,
              Espacio.lateral,
              96,
            ),
            children: [
              const _Cabecera(),
              if (lista.isEmpty)
                const EstadoVacio(
                  icono: Iconos.banco,
                  titulo: 'Aún no hay cuentas',
                  texto:
                      'Añade tus bancos, billeteras y el efectivo para saber '
                      'cuánto tienes de verdad.',
                )
              else
                Seccion(
                  titulo: 'Tus cuentas',
                  accion: 'Toca una para anotar su saldo',
                  child: Panel.lista(
                    filas: [
                      for (final cuenta in lista) _FilaCuenta(cuenta: cuenta),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva cuenta',
        onPressed: () => _nuevaCuenta(context, ref),
        child: const Icon(Iconos.anadir),
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
/// Lo que hay entre todas las cuentas y si coincide con lo que calcula la app.
class _Cabecera extends ConsumerWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(dineroRealProvider).valueOrNull ?? 0;
    final inicio = ref.watch(inicioProvider).valueOrNull;
    final r = inicio?.resumen;
    final diferencia = r == null ? null : total - r.disponibleHoy;

    return Padding(
      padding: const EdgeInsets.only(top: Espacio.m),
      child: CifraPrincipal(
        etiqueta: 'Tienes hoy entre todas',
        valor: total,
        debajo: [
          if (diferencia != null)
            diferencia.abs() < DatosInicio.toleranciaCuadre
                ? const Etiqueta(
                    'Cuadra con la app',
                    tono: Tono.positivo,
                    icono: Iconos.listo,
                    grande: true,
                  )
                : Etiqueta(
                    diferencia > 0
                        ? 'Tienes ${Formato.pesos(diferencia)} más que la app'
                        : 'Te faltan ${Formato.pesos(-diferencia)} frente a la app',
                    tono: Tono.aviso,
                    icono: Iconos.atencion,
                    grande: true,
                  ),
        ],
      ),
    );
  }
}

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
    TipoCuenta.banco => Iconos.banco,
    TipoCuenta.billetera => Iconos.billetera,
    TipoCuenta.efectivo => Iconos.efectivo,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dias = cuenta.diasSinActualizar;
    final cuando = dias == 0
        ? 'hoy'
        : dias == 1
        ? 'ayer'
        : 'el ${Formato.fechaCorta(cuenta.saldoAl)}';
    // Si se apuntó algo después de anotar el saldo, se dice cuánto: así se entiende por qué la
    // cifra no es la que se anotó.
    final antiguedad = cuenta.cambio.abs() >= 1
        ? 'Anotado ${Formato.pesos(cuenta.saldoAnotado)} $cuando · '
              '${cuenta.cambio < 0 ? '−' : '+'}${Formato.pesos(cuenta.cambio.abs())} después'
        : dias == 0
        ? 'Actualizado hoy'
        : dias == 1
        ? 'Actualizado ayer'
        : 'Hace $dias días · ${Formato.fechaCorta(cuenta.saldoAl)}';

    final c = context.colores;
    return Opacity(
      opacity: cuenta.activa ? 1 : 0.5,
      child: GestureDetector(
        onLongPress: () => _opciones(context, ref),
        child: Fila(
          inicio: IconoCaja(_icono),
          titulo: cuenta.nombre,
          // Un saldo de hace más de una semana ya no sirve para cuadrar: se avisa.
          etiqueta: dias > 7 && cuenta.activa
              ? const Etiqueta('Revisar', tono: Tono.aviso)
              : null,
          subtitulo: cuenta.activa ? antiguedad : 'Archivada',
          // Con centavos: es la cifra que se compara contra la del banco.
          final_: Text(
            Formato.dinero(cuenta.saldo),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.tinta,
            ),
          ),
          alTocar: () => _anotarSaldo(context, ref),
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
