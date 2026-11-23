import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../dominio/detectados.dart';
import '../../dominio/modelos.dart';
import '../../estado/detectados.dart';
import '../../estado/movimientos.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';

/// Decide qué hacer con un movimiento que llegó del banco: registrarlo (como compra, gasto,
/// ingreso o abono a una deuda), decir que ya estaba apuntado o descartarlo.
class HojaRevisar extends ConsumerStatefulWidget {
  const HojaRevisar({required this.detectado, super.key});

  final Detectado detectado;

  static Future<void> abrir(BuildContext context, Detectado d) =>
      abrirHoja<void>(
        context,
        titulo: d.entra ? 'Entró plata' : 'Salió plata',
        subtitulo: [
          d.etiquetaClase,
          Formato.fecha(d.fecha),
          if (d.hora != null) d.hora!.substring(0, 5),
          'por ${d.etiquetaOrigen.toLowerCase()}',
        ].join(' · '),
        contenido: (_) => HojaRevisar(detectado: d),
      );

  @override
  ConsumerState<HojaRevisar> createState() => _EstadoHojaRevisar();
}

class _EstadoHojaRevisar extends ConsumerState<HojaRevisar> {
  late DestinoDetectado _destino;
  late final TextEditingController _nombre;
  CategoriaGasto _categoria = CategoriaGasto.otro;
  TipoIngreso _tipoIngreso = TipoIngreso.otro;
  MedioPago _medio = MedioPago.debito;
  String? _deudaId;
  bool _siempre = false;
  bool _enviando = false;

  Detectado get _d => widget.detectado;

  /// Los destinos que tienen sentido según hacia dónde fue la plata.
  List<DestinoDetectado> get _destinos => _d.entra
      ? const [DestinoDetectado.ingreso, DestinoDetectado.abono]
      : const [
          DestinoDetectado.compra,
          DestinoDetectado.gasto,
          DestinoDetectado.abono,
        ];

  @override
  void initState() {
    super.initState();
    final sugerido = _d.sugerenciaDestino;
    _destino = sugerido != null && _destinos.contains(sugerido)
        ? sugerido
        : _destinos.first;
    _nombre = TextEditingController(text: _d.nombreSugerido);
    _categoria = _d.categoriaSugerida ?? CategoriaGasto.otro;
    _tipoIngreso = _d.tipoIngresoSugerido ?? TipoIngreso.otro;
    _deudaId = _d.sugerenciaObjetivo;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _hacer(Future<void> Function() accion, String mensaje) async {
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    setState(() => _enviando = true);
    try {
      await accion();
      navegador.pop();
      mensajero.showSnackBar(SnackBar(content: Text(mensaje)));
      await refrescarSecciones(ref);
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _registrar() {
    final repo = ref.read(repositorioDetectadosProvider);
    return _hacer(
      () => repo.aceptar(
        _d.id,
        destino: _destino,
        descripcion: _destino == DestinoDetectado.abono
            ? null
            : _nombre.text.trim(),
        categoria:
            _destino == DestinoDetectado.compra ||
                _destino == DestinoDetectado.gasto
            ? _categoria
            : null,
        tipoIngreso: _destino == DestinoDetectado.ingreso ? _tipoIngreso : null,
        medio: _destino == DestinoDetectado.compra ? _medio : null,
        deudaId: _destino == DestinoDetectado.abono ? _deudaId : null,
        siempre: _siempre,
      ),
      'Quedó registrado',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = context.colores;
    final contraparte = _d.contraparte;
    final puedeRegistrar =
        !_enviando &&
        (_destino != DestinoDetectado.abono || _deudaId != null) &&
        (_destino == DestinoDetectado.abono || _nombre.text.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          Formato.pesosConSigno(_d.monto),
          style: Tipo.estilo(34, 700, color: _d.entra ? c.positivo : c.tinta),
        ),
        if (contraparte != null) ...[
          const SizedBox(height: Espacio.xs),
          Text(
            [contraparte, ?_d.referencia].join(' · '),
            style: textos.bodyMedium?.copyWith(color: c.tinta2),
          ),
        ],
        const SizedBox(height: Espacio.xl),
        SegmentedButton<DestinoDetectado>(
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          segments: [
            for (final d in _destinos)
              ButtonSegment(
                value: d,
                label: Text(
                  d == DestinoDetectado.abono && _d.entra
                      ? 'Me pagaron'
                      : d.etiqueta,
                ),
              ),
          ],
          selected: {_destino},
          onSelectionChanged: (s) => setState(() => _destino = s.first),
        ),
        const SizedBox(height: Espacio.l),
        if (_destino == DestinoDetectado.abono)
          _ElegirDeuda(
            entra: _d.entra,
            elegida: _deudaId,
            alElegir: (id) => setState(() => _deudaId = id),
          )
        else ...[
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: Espacio.l),
          _Titulo(_destino == DestinoDetectado.ingreso ? 'Tipo' : 'Categoría'),
          if (_destino == DestinoDetectado.ingreso)
            _Chips(
              hijos: [
                for (final t in TipoIngreso.alApuntar)
                  ChoiceChip(
                    avatar: Icon(
                      Iconos.deIngreso(t),
                      size: 18,
                      color: _tipoIngreso == t ? c.sobreAcento : c.tinta2,
                    ),
                    label: Text(t.etiqueta),
                    selected: _tipoIngreso == t,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _tipoIngreso = t),
                  ),
              ],
            )
          else
            _Chips(
              hijos: [
                for (final cat
                    in _destino == DestinoDetectado.compra
                        ? CategoriaGasto.deCompras
                        : CategoriaGasto.values)
                  ChoiceChip(
                    avatar: Icon(
                      Iconos.deCategoria(cat),
                      size: 18,
                      color: _categoria == cat ? c.sobreAcento : c.tinta2,
                    ),
                    label: Text(cat.etiqueta),
                    selected: _categoria == cat,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _categoria = cat),
                  ),
              ],
            ),
          if (_destino == DestinoDetectado.compra) ...[
            const SizedBox(height: Espacio.l),
            const _Titulo('Pagaste con'),
            _Chips(
              hijos: [
                for (final m in [MedioPago.debito, MedioPago.efectivo])
                  ChoiceChip(
                    label: Text(m.etiqueta),
                    selected: _medio == m,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _medio = m),
                  ),
              ],
            ),
          ],
        ],
        if (contraparte != null || _d.referencia != null) ...[
          const SizedBox(height: Espacio.m),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _siempre,
            onChanged: (v) => setState(() => _siempre = v),
            title: const Text('Hacerlo siempre así'),
            subtitle: Text(
              'Lo próximo de ${_d.referencia ?? contraparte} llegará ya '
              'listo, o descartado si lo descartas',
              style: textos.bodySmall?.copyWith(color: c.tinta2),
            ),
          ),
        ],
        const SizedBox(height: Espacio.l),
        FilledButton(
          onPressed: puedeRegistrar ? _registrar : null,
          child: Text(_enviando ? 'Guardando…' : 'Registrar'),
        ),
        const SizedBox(height: Espacio.s),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _enviando
                    ? null
                    : () => _hacer(
                        () => ref
                            .read(repositorioDetectadosProvider)
                            .yaRegistrado(_d.id),
                        'Marcado como ya apuntado',
                      ),
                child: const Text('Ya estaba apuntado'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _enviando
                    ? null
                    : () => _hacer(
                        () => ref
                            .read(repositorioDetectadosProvider)
                            .descartar(_d.id, siempre: _siempre),
                        _siempre
                            ? 'Descartado, y lo de ahí se descartará solo'
                            : 'Descartado',
                      ),
                child: const Text('Descartar'),
              ),
            ),
          ],
        ),
        if (_d.texto.isNotEmpty) ...[
          const SizedBox(height: Espacio.m),
          Text(_d.texto, style: textos.bodySmall?.copyWith(color: c.tinta3)),
        ],
      ],
    );
  }
}

class _ElegirDeuda extends ConsumerWidget {
  const _ElegirDeuda({
    required this.entra,
    required this.elegida,
    required this.alElegir,
  });

  final bool entra;
  final String? elegida;
  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final c = context.colores;
    return ref
        .watch(deudasParaAbonarProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text(e is ErrorApi ? e.mensaje : 'No se pudo cargar'),
          data: (todas) {
            // Plata que sale abona a lo que debes; plata que entra es un cobro de lo que te
            // deben.
            final deudas = todas.where((d) => d.aFavor == entra).toList();
            if (deudas.isEmpty) {
              return Text(
                entra
                    ? 'No tienes nada registrado en «Te deben».'
                    : 'No tienes deudas con saldo.',
                style: textos.bodyMedium?.copyWith(color: c.tinta2),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Titulo(entra ? '¿Quién te pagó?' : '¿A qué deuda?'),
                _Chips(
                  hijos: [
                    for (final d in deudas)
                      ChoiceChip(
                        label: Text(d.acreedor),
                        selected: elegida == d.id,
                        showCheckmark: false,
                        onSelected: (_) => alElegir(d.id),
                      ),
                  ],
                ),
              ],
            );
          },
        );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Espacio.s),
    child: Text(
      texto,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: context.colores.tinta2),
    ),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.hijos});

  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: hijos);
}
