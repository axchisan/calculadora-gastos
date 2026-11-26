import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dinero.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../datos/foto_de_meta.dart';
import '../../datos/repositorio_ahorro.dart';
import '../../datos/selector_pdf.dart';
import '../../dominio/modelos.dart';
import '../../dominio/plan.dart';
import '../../estado/ahorro.dart';
import '../../estado/mes.dart';
import '../../estado/plan.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';
import 'ilustracion_meta.dart';

/// «Mi plan»: cuánto sobra del sueldo cada mes después de pagar todo, y cuándo llega la meta.
///
/// Arriba la meta (con su foto o el teléfono dibujado, cuánto falta, cuándo se alcanza y cuánto
/// apartar al mes); debajo, mes por mes, lo que entra, lo que sale y lo que sobra.
class PantallaPlan extends ConsumerWidget {
  const PantallaPlan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(planProvider);
    final ancho = Pantalla.esEscritorio(context) ? 680.0 : double.infinity;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi plan')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: datos.when(
            skipLoadingOnRefresh: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EstadoVacio(
              icono: Iconos.sinConexion,
              titulo: 'No se pudo calcular el plan',
              texto: e is ErrorApi ? e.mensaje : 'Inténtalo de nuevo',
              accion: 'Reintentar',
              alTocarAccion: () => ref.invalidate(planProvider),
            ),
            data: (plan) => RefreshIndicator(
              onRefresh: () => ref.refresh(planProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Espacio.lateral,
                  Espacio.s,
                  Espacio.lateral,
                  48,
                ),
                children: [
                  if (plan.metas.isEmpty)
                    _SinMeta(plan: plan)
                  else
                    for (final m in plan.metas)
                      _TarjetaMeta(meta: m, plan: plan),
                  Seccion(
                    titulo: 'Mes a mes',
                    child: Column(
                      children: [
                        _DiaADia(plan: plan),
                        for (final mes in plan.meses) ...[
                          const SizedBox(height: Espacio.m),
                          _TarjetaMes(mes: mes),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Espacio.l),
                  Text(
                    'El sueldo de los meses que vienen es una estimación con la TRM de hoy. '
                    'Las deudas sin cuadro se cuentan con su cuota hasta saldarse.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colores.tinta3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _cuando(DateTime? mes) => mes == null
    ? 'no alcanza en el próximo año'
    : 'en ${Formato.mesEnFrase(mes)}';

/// El mes en que se completaría lo que falta apartando [aporte] cada mes (o lo que sobre, si
/// es menos). Se calcula en la app para que el control responda al instante.
DateTime? _alcanzaCon(Plan plan, double faltan, double aporte) {
  if (faltan <= 0) return plan.meses.first.periodo;
  var junto = 0.0;
  for (final mes in plan.meses.skip(1)) {
    final disponible = mes.sobra < 0 ? 0.0 : mes.sobra;
    junto += aporte < disponible ? aporte : disponible;
    if (junto >= faltan) return mes.periodo;
  }
  return null;
}

class _TarjetaMeta extends ConsumerStatefulWidget {
  const _TarjetaMeta({required this.meta, required this.plan});

  final MetaPlan meta;
  final Plan plan;

  @override
  ConsumerState<_TarjetaMeta> createState() => _EstadoTarjetaMeta();
}

class _EstadoTarjetaMeta extends ConsumerState<_TarjetaMeta> {
  Uint8List? _foto;
  double? _aporte;
  bool _guardando = false;

  MetaPlan get _m => widget.meta;

  @override
  void initState() {
    super.initState();
    _cargarFoto();
  }

  Future<void> _cargarFoto() async {
    final f = await const FotoDeMeta().leer(_m.id);
    if (mounted) setState(() => _foto = f);
  }

  Future<void> _opcionesFoto() async {
    final mensajero = ScaffoldMessenger.of(context);
    final eleccion = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Iconos.editar),
              title: const Text('Elegir foto'),
              subtitle: const Text('Se guarda solo en este dispositivo'),
              onTap: () => Navigator.pop(contexto, 'elegir'),
            ),
            if (_foto != null)
              ListTile(
                leading: const Icon(Iconos.borrar),
                title: const Text('Volver al dibujo'),
                onTap: () => Navigator.pop(contexto, 'quitar'),
              ),
          ],
        ),
      ),
    );
    if (eleccion == 'quitar') {
      await const FotoDeMeta().quitar(_m.id);
      if (mounted) setState(() => _foto = null);
    } else if (eleccion == 'elegir') {
      final bytes = await elegirImagen();
      if (bytes == null) return;
      if (!await const FotoDeMeta().guardar(_m.id, bytes)) {
        mensajero.showSnackBar(
          const SnackBar(content: Text('La foto pesa demasiado (máximo 3 MB)')),
        );
        return;
      }
      if (mounted) setState(() => _foto = bytes);
    }
  }

  /// El tope del control: lo que sobra en promedio, redondeado hacia arriba a 100.000.
  double get _maximo {
    final base = [
      widget.plan.sobraPromedio,
      _m.valor,
      100000.0,
    ].reduce((a, b) => a > b ? a : b);
    return (base / 100000).ceil() * 100000.0;
  }

  Future<void> _guardarAporte(double valor) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      await ref
          .read(repositorioAhorroProvider)
          .actualizar(
            _m.id,
            tipoAsignacion: TipoAsignacion.montoFijo,
            valor: valor,
          );
      ref.invalidate(planProvider);
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
          _aporte = null;
        });
      }
    }
  }

  Future<void> _apartar() async {
    final campo = TextEditingController(
      text: Dinero.paraEditar(
        _m.aporteMensual > 0 ? _m.aporteMensual : _m.valor,
      ),
    );
    final monto = await abrirHoja<double>(
      context,
      titulo: 'Apartar para ${_m.nombre}',
      subtitulo: 'Sale del disponible del mes y suma a la meta',
      contenido: (contexto) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: campo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoDeImporte()],
            decoration: const InputDecoration(
              labelText: 'Cuánto',
              prefixText: r'$ ',
            ),
          ),
          const SizedBox(height: Espacio.l),
          FilledButton(
            onPressed: () =>
                Navigator.pop(contexto, Dinero.interpretar(campo.text)),
            child: const Text('Apartar'),
          ),
        ],
      ),
    );
    if (monto == null || monto <= 0 || !mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(repositorioAhorroProvider)
          .registrarMovimiento(
            _m.id,
            tipo: TipoMovimiento.aporte,
            monto: monto,
            mesId: ref.read(mesIdProvider),
          );
      ref.invalidate(planProvider);
      ref.invalidate(ahorroProvider);
      mensajero.showSnackBar(
        SnackBar(content: Text('Apartaste ${Formato.pesos(monto)}')),
      );
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = context.colores;
    final aporte = _aporte ?? _m.valor;
    final cuando = _aporte == null
        ? _m.alcanzaEn
        : _alcanzaCon(widget.plan, _m.faltan, aporte);
    final completa = _m.faltan <= 0;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _opcionesFoto,
                child: IlustracionMeta(progreso: _m.progreso, foto: _foto),
              ),
              const SizedBox(width: Espacio.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_m.nombre, style: textos.titleLarge),
                    const SizedBox(height: Espacio.xs),
                    Text(
                      '${Formato.pesos(_m.ahorrado)} de ${Formato.pesos(_m.objetivo)}',
                      style: textos.bodyMedium?.copyWith(color: c.tinta2),
                    ),
                    const SizedBox(height: Espacio.m),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _m.progreso,
                        minHeight: 8,
                        color: colorBorgona,
                        backgroundColor: colorBorgona.withValues(alpha: 0.14),
                      ),
                    ),
                    const SizedBox(height: Espacio.m),
                    Text(
                      completa
                          ? '¡Ya la tienes completa!'
                          : 'Te faltan ${Formato.pesos(_m.faltan)}',
                      style: textos.titleMedium,
                    ),
                    if (!completa)
                      Text(
                        'Apartando ${Formato.pesos(aporte)} al mes la tienes '
                        '${_cuando(cuando)}.',
                        style: textos.bodyMedium,
                      ),
                    if (!completa && _m.alcanzaEnConTodo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Espacio.xs),
                        child: Text(
                          'Con todo lo que te sobra: '
                          '${Formato.mesEnFrase(_m.alcanzaEnConTodo!)}.',
                          style: textos.bodySmall?.copyWith(color: c.tinta2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!completa) ...[
            const SizedBox(height: Espacio.l),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Apartar al mes',
                    style: textos.labelLarge?.copyWith(color: c.tinta2),
                  ),
                ),
                Text(
                  Formato.pesos(aporte),
                  style: textos.titleSmall?.copyWith(
                    color: colorBorgona,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: aporte.clamp(0, _maximo).toDouble(),
              max: _maximo,
              divisions: (_maximo / 50000).round(),
              label: Formato.pesos(aporte),
              activeColor: colorBorgona,
              onChanged: _guardando ? null : (v) => setState(() => _aporte = v),
              onChangeEnd: _guardando ? null : _guardarAporte,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _apartar,
                    child: const Text('Apartar ahora'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SinMeta extends ConsumerWidget {
  const _SinMeta({required this.plan});

  final Plan plan;

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final nombre = TextEditingController();
    final objetivo = TextEditingController();
    final aporte = TextEditingController(
      text: plan.sobraPromedio > 0
          ? Dinero.paraEditar(
              ((plan.sobraPromedio * 0.7) / 50000).floor() * 50000.0,
            )
          : '',
    );
    final creada = await abrirHoja<bool>(
      context,
      titulo: 'Nueva meta',
      subtitulo: 'Algo que quieres comprar o juntar',
      contenido: (contexto) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nombre,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: '¿Qué es?'),
          ),
          const SizedBox(height: Espacio.m),
          TextField(
            controller: objetivo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoDeImporte()],
            decoration: const InputDecoration(
              labelText: '¿Cuánto cuesta?',
              prefixText: r'$ ',
            ),
          ),
          const SizedBox(height: Espacio.m),
          TextField(
            controller: aporte,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoDeImporte()],
            decoration: const InputDecoration(
              labelText: 'Apartar al mes',
              prefixText: r'$ ',
            ),
          ),
          const SizedBox(height: Espacio.l),
          FilledButton(
            onPressed: () async {
              final o = Dinero.interpretar(objetivo.text);
              if (nombre.text.trim().isEmpty || o == null || o <= 0) return;
              await ref
                  .read(repositorioAhorroProvider)
                  .crear(
                    nombre: nombre.text.trim(),
                    tipoAsignacion: TipoAsignacion.montoFijo,
                    valor: Dinero.interpretar(aporte.text) ?? 0,
                    metaMonto: o,
                  );
              if (contexto.mounted) Navigator.pop(contexto, true);
            },
            child: const Text('Crear meta'),
          ),
        ],
      ),
    );
    if (creada == true) ref.invalidate(planProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final proximo = plan.proximo;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IlustracionMeta(progreso: 0.15, alto: 96),
              const SizedBox(width: Espacio.l),
              Expanded(
                child: Text(
                  proximo == null
                      ? 'Ponte una meta y te digo cuándo la alcanzas.'
                      : 'En ${Formato.nombreDeMes(proximo.periodo.month).toLowerCase()} '
                            'te sobran ${Formato.pesos(proximo.sobra)} después de pagar '
                            'todo. Ponte una meta y te digo cuándo la alcanzas.',
                  style: textos.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.l),
          FilledButton(
            onPressed: () => _crear(context, ref),
            child: const Text('Crear una meta'),
          ),
        ],
      ),
    );
  }
}

/// El gasto del día a día que se usa en el plan, con opción de cambiarlo.
class _DiaADia extends ConsumerWidget {
  const _DiaADia({required this.plan});

  final Plan plan;

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final campo = TextEditingController(
      text: Dinero.paraEditar(plan.gastoDiario),
    );
    final resultado = await abrirHoja<(bool, double?)>(
      context,
      titulo: 'Día a día',
      subtitulo:
          'Comida, antojos, transporte… Según tus compras, unos '
          '${Formato.pesos(plan.gastoDiarioEstimado)} al mes.',
      contenido: (contexto) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: campo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [FormatoDeImporte()],
            decoration: const InputDecoration(
              labelText: 'Al mes',
              prefixText: r'$ ',
            ),
          ),
          const SizedBox(height: Espacio.l),
          FilledButton(
            onPressed: () =>
                Navigator.pop(contexto, (true, Dinero.interpretar(campo.text))),
            child: const Text('Usar esta cifra'),
          ),
          if (plan.gastoDiarioPropio)
            TextButton(
              onPressed: () => Navigator.pop(contexto, (true, null)),
              child: const Text('Volver a la estimación'),
            ),
        ],
      ),
    );
    if (resultado == null || !resultado.$1) return;
    await ref.read(repositorioPlanProvider).fijarGastoDiario(resultado.$2);
    ref.invalidate(planProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Panel.lista(
      filas: [
        Fila(
          inicio: const IconoCaja(Iconos.efectivo),
          titulo: 'Día a día: ${Formato.pesos(plan.gastoDiario)} al mes',
          subtitulo: plan.gastoDiarioPropio
              ? 'Puesto por ti · toca para cambiarlo'
              : 'Estimado con tus compras · toca para cambiarlo',
          final_: Icon(Iconos.editar, color: context.colores.tinta3, size: 20),
          alTocar: () => _editar(context, ref),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          value: ref.watch(restarDiaADiaProvider),
          onChanged: (v) => ref.read(restarDiaADiaProvider.notifier).cambiar(v),
          title: const Text('Restar el día a día'),
          subtitle: Text(
            'Apagado, lo que sobra es después de gastos fijos, deudas y créditos. '
            'La fecha de la meta siempre lo cuenta.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.colores.tinta2),
          ),
        ),
      ],
    );
  }
}

class _TarjetaMes extends ConsumerStatefulWidget {
  const _TarjetaMes({required this.mes});

  final MesPlan mes;

  @override
  ConsumerState<_TarjetaMes> createState() => _EstadoTarjetaMes();
}

class _EstadoTarjetaMes extends ConsumerState<_TarjetaMes> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mes;
    final textos = Theme.of(context).textTheme;
    final c = context.colores;
    final nombre = Formato.mesYAnio(m.periodo);
    final restar = ref.watch(restarDiaADiaProvider);
    final sobra = sobraSegun(m, restarDiaADia: restar);

    Widget fila(
      String etiqueta,
      double valor, {
      String? nota,
      bool entra = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: etiqueta,
                children: [
                  if (nota != null)
                    TextSpan(
                      text: ' · $nota',
                      style: TextStyle(color: c.tinta3),
                    ),
                ],
              ),
              style: textos.bodyMedium,
            ),
          ),
          Text(
            entra ? '+${Formato.pesos(valor)}' : '−${Formato.pesos(valor)}',
            style: textos.bodyMedium?.copyWith(
              color: entra ? c.positivo : c.tinta,
            ),
          ),
        ],
      ),
    );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.actual ? '$nombre · lo que falta' : nombre,
                  style: textos.titleMedium,
                ),
              ),
              Text(
                sobra < 0
                    ? 'Faltan ${Formato.pesos(-sobra)}'
                    : 'Sobran ${Formato.pesos(sobra)}',
                style: textos.titleMedium?.copyWith(
                  color: sobra < 0 ? c.negativo : c.positivo,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espacio.s),
          if (m.actual)
            fila('Tienes hoy', m.ingreso, entra: true)
          else
            fila(
              'Sueldo',
              m.ingreso,
              entra: true,
              nota: m.ingresoEstimado ? 'estimado' : null,
            ),
          if (m.fijos > 0)
            fila(m.actual ? 'Gastos fijos por pagar' : 'Gastos fijos', m.fijos),
          if (m.totalPagos > 0)
            InkWell(
              onTap: () => setState(() => _abierto = !_abierto),
              child: fila(
                'Deudas y créditos',
                m.totalPagos,
                nota: _abierto ? 'ocultar' : 'ver',
              ),
            ),
          if (_abierto)
            for (final p in m.pagos)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.nombre} · ${Formato.fechaCorta(p.fecha)}',
                        style: textos.bodySmall?.copyWith(color: c.tinta2),
                      ),
                    ),
                    Text(
                      Formato.pesos(p.monto),
                      style: textos.bodySmall?.copyWith(color: c.tinta2),
                    ),
                  ],
                ),
              ),
          if (restar) fila('Día a día', m.diario),
        ],
      ),
    );
  }
}
