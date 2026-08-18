import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../datos/cliente_api.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/capturas.dart';
import '../../../estado/compras.dart';
import 'guia_permiso.dart';

/// Alta y edición de las tarjetas con las que se paga.
///
/// Lo importante de una tarjeta de crédito aquí son sus dos días: el de corte y el de pago. Son
/// los que deciden de qué mes sale el dinero de cada compra, y son la razón de que una tarjeta
/// descuadre las cuentas cuando se lleva de memoria.
class GestionTarjetas extends ConsumerWidget {
  const GestionTarjetas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tarjetas = ref.watch(tarjetasProvider);
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tarjetas', style: tema.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'El día de corte y el de pago deciden de qué mes sale lo que compras a crédito.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          tarjetas.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No se pudieron cargar las tarjetas'),
            ),
            data: (lista) => Column(
              children: [
                for (final tarjeta in lista)
                  _FilaTarjeta(key: ValueKey(tarjeta.id), tarjeta: tarjeta),
                if (lista.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Todavía no hay tarjetas.',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _nueva(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Añadir tarjeta'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 8),
          const _PermisoDeCapturas(),
        ],
      ),
    );
  }

  Future<void> _nueva(BuildContext context, WidgetRef ref) async {
    final datos = await showModalBottomSheet<_DatosTarjeta>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FormularioTarjeta(),
    );
    if (datos == null) return;

    try {
      await ref
          .read(controladorTarjetasProvider)
          .crear(
            nombre: datos.nombre,
            tipo: datos.tipo,
            diaCorte: datos.diaCorte,
            diaPago: datos.diaPago,
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

class _FilaTarjeta extends ConsumerWidget {
  const _FilaTarjeta({required this.tarjeta, super.key});

  final Tarjeta tarjeta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        tarjeta.esDeCredito
            ? Icons.credit_card
            : Icons.account_balance_outlined,
        color: tarjeta.activa
            ? tema.colorScheme.primary
            : tema.colorScheme.outline,
      ),
      title: Text(
        tarjeta.nombre,
        style: TextStyle(
          decoration: tarjeta.activa ? null : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Text(
        [
          tarjeta.tipo.etiqueta,
          ?tarjeta.resumenCiclo,
          if (tarjeta.alias.isNotEmpty)
            '${tarjeta.alias.length} '
                '${tarjeta.alias.length == 1 ? 'apodo' : 'apodos'}',
          if (!tarjeta.activa) 'archivada',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Cómo se reconoce en las notificaciones',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _AliasDeTarjeta(tarjeta: tarjeta),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            onPressed: () => _eliminar(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('¿Eliminar ${tarjeta.nombre}?'),
        content: const Text(
          'Si ya tiene compras registradas se archivará en lugar de borrarse, '
          'para no dejar esas compras sin explicar de dónde salió el dinero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await ref.read(controladorTarjetasProvider).eliminar(tarjeta.id);
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

/// Enseña a la aplicación a reconocer una tarjeta en las notificaciones de pago.
///
/// Es lo que traduce el «crédito física» de Google Wallet, o el «terminada en 2355» del banco,
/// a la tarjeta de aquí. De esa traducción depende algo que no es menor: si la compra salió del
/// dinero de hoy o se va al corte del mes que viene.
class _AliasDeTarjeta extends ConsumerStatefulWidget {
  const _AliasDeTarjeta({required this.tarjeta});

  final Tarjeta tarjeta;

  @override
  ConsumerState<_AliasDeTarjeta> createState() => _AliasDeTarjetaState();
}

class _AliasDeTarjetaState extends ConsumerState<_AliasDeTarjeta> {
  final _apodo = TextEditingController();
  final _ultimos4 = TextEditingController();

  @override
  void dispose() {
    _apodo.dispose();
    _ultimos4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    // Se lee de la lista viva para que la pantalla se actualice al añadir o quitar un apodo.
    final tarjeta = ref
        .watch(tarjetasProvider)
        .maybeWhen(
          data: (lista) => lista.firstWhere(
            (t) => t.id == widget.tarjeta.id,
            orElse: () => widget.tarjeta,
          ),
          orElse: () => widget.tarjeta,
        );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tarjeta.nombre, style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Cómo aparece esta tarjeta en las notificaciones de pago del teléfono.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            for (final alias in tarjeta.alias)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  alias.ultimos4 != null
                      ? Icons.pin_outlined
                      : Icons.badge_outlined,
                  size: 20,
                ),
                title: Text(alias.apodo ?? '•••• ${alias.ultimos4}'),
                subtitle: alias.apodo != null && alias.ultimos4 != null
                    ? Text('•••• ${alias.ultimos4}')
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _eliminar(alias.id),
                ),
              ),

            if (tarjeta.alias.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Todavía no se reconoce sola.',
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            const Divider(height: 28),
            TextField(
              controller: _apodo,
              decoration: const InputDecoration(
                labelText: 'Apodo en Google Wallet',
                hintText: 'crédito física',
                helperText: 'El nombre que le pusiste dentro de la billetera',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ultimos4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Últimos cuatro dígitos',
                hintText: '2355',
                helperText: 'Los que publica el banco; es el dato más fiable',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _anadir,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _anadir() async {
    final apodo = _apodo.text.trim();
    final digitos = _ultimos4.text.trim();

    if (apodo.isEmpty && digitos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el apodo o los cuatro dígitos')),
      );
      return;
    }

    try {
      await ref
          .read(controladorTarjetasProvider)
          .anadirAlias(
            widget.tarjeta.id,
            apodo: apodo.isEmpty ? null : apodo,
            ultimos4: digitos.isEmpty ? null : digitos,
          );
      _apodo.clear();
      _ultimos4.clear();
    } on ErrorApi catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }

  Future<void> _eliminar(String aliasId) async {
    try {
      await ref.read(controladorTarjetasProvider).eliminarAlias(aliasId);
    } on ErrorApi catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

/// Estado del permiso para leer las notificaciones de pago.
class _PermisoDeCapturas extends ConsumerWidget {
  const _PermisoDeCapturas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capturaDisponibleProvider)) return const SizedBox.shrink();

    final tema = Theme.of(context);
    final concedido = ref
        .watch(permisoCapturaProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          concedido
              ? Icons.notifications_active
              : Icons.notifications_off_outlined,
          color: concedido
              ? tema.colorScheme.primary
              : tema.colorScheme.outline,
        ),
        title: Text(
          concedido
              ? 'Detectando pagos automáticamente'
              : 'Detectar pagos automáticamente',
        ),
        subtitle: Text(
          concedido
              ? 'Los pagos con el teléfono aparecen en Gastos diarios para confirmarlos.'
              : 'Hace falta darle acceso a las notificaciones en los ajustes de Android.',
        ),
        trailing: concedido ? null : const Icon(Icons.open_in_new, size: 18),
        // Se abre la guía en lugar de saltar directamente a Ajustes. Ir derecho ahí dejaba al
        // usuario delante de un interruptor apagado que no se deja tocar, sin ninguna pista de
        // que el paso que falta está escondido en otro menú.
        onTap: concedido
            ? null
            : () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const GuiaPermiso(),
              ),
      ),
    );
  }
}

class _DatosTarjeta {
  const _DatosTarjeta({
    required this.nombre,
    required this.tipo,
    this.diaCorte,
    this.diaPago,
  });

  final String nombre;
  final TipoTarjeta tipo;
  final int? diaCorte;
  final int? diaPago;
}

class _FormularioTarjeta extends StatefulWidget {
  const _FormularioTarjeta();

  @override
  State<_FormularioTarjeta> createState() => _FormularioTarjetaState();
}

class _FormularioTarjetaState extends State<_FormularioTarjeta> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();

  TipoTarjeta _tipo = TipoTarjeta.credito;
  int _diaCorte = 15;
  int _diaPago = 4;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formulario,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nueva tarjeta', style: tema.textTheme.titleLarge),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Nu, Bancolombia, Falabella…',
                ),
                validator: (valor) =>
                    (valor ?? '').trim().isEmpty ? 'Ponle un nombre' : null,
              ),
              const SizedBox(height: 20),

              SegmentedButton<TipoTarjeta>(
                segments: const [
                  ButtonSegment(
                    value: TipoTarjeta.debito,
                    icon: Icon(Icons.account_balance_outlined),
                    label: Text('Débito'),
                  ),
                  ButtonSegment(
                    value: TipoTarjeta.credito,
                    icon: Icon(Icons.credit_card),
                    label: Text('Crédito'),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),

              if (_tipo == TipoTarjeta.credito) ...[
                const SizedBox(height: 20),
                _SelectorDia(
                  etiqueta: 'Día de corte',
                  ayuda: 'El día en que cierra el periodo de consumo',
                  valor: _diaCorte,
                  alCambiar: (dia) => setState(() => _diaCorte = dia),
                ),
                const SizedBox(height: 12),
                _SelectorDia(
                  etiqueta: 'Día de pago',
                  ayuda: 'El día del mes siguiente en que hay que pagarlo',
                  valor: _diaPago,
                  alCambiar: (dia) => setState(() => _diaPago = dia),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Una compra del día $_diaCorte se paga el $_diaPago del mes '
                    'siguiente. Una del ${_diaCorte + 1} espera al corte siguiente '
                    'y se paga un mes más tarde.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.primary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmar,
                      child: const Text('Añadir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmar() {
    if (!_formulario.currentState!.validate()) return;

    final esCredito = _tipo == TipoTarjeta.credito;
    Navigator.pop(
      context,
      _DatosTarjeta(
        nombre: _nombre.text.trim(),
        tipo: _tipo,
        diaCorte: esCredito ? _diaCorte : null,
        diaPago: esCredito ? _diaPago : null,
      ),
    );
  }
}

class _SelectorDia extends StatelessWidget {
  const _SelectorDia({
    required this.etiqueta,
    required this.ayuda,
    required this.valor,
    required this.alCambiar,
  });

  final String etiqueta;
  final String ayuda;
  final int valor;
  final void Function(int) alCambiar;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: valor,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
      // Hasta 28 para que el día exista en todos los meses, febrero incluido.
      items: [
        for (var dia = 1; dia <= 28; dia++)
          DropdownMenuItem(value: dia, child: Text('$dia')),
      ],
      onChanged: (dia) {
        if (dia != null) alCambiar(dia);
      },
    );
  }
}
