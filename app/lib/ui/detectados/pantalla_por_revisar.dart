import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../datos/selector_pdf.dart';
import '../../dominio/detectados.dart';
import '../../estado/detectados.dart';
import '../../estado/movimientos.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';
import 'hoja_revisar.dart';

/// «Por revisar»: lo que llegó del banco (SMS, correo, extracto) y aún no está en la app.
///
/// Nada se registra solo: cada movimiento se registra, se marca como ya apuntado o se descarta.
/// Lo que una regla del usuario ya sabe cómo registrar se acepta en bloque.
class PantallaPorRevisar extends ConsumerStatefulWidget {
  const PantallaPorRevisar({super.key});

  @override
  ConsumerState<PantallaPorRevisar> createState() => _EstadoPorRevisar();
}

class _EstadoPorRevisar extends ConsumerState<PantallaPorRevisar> {
  bool _importando = false;
  bool _aceptando = false;
  String? _resultado;

  @override
  void initState() {
    super.initState();
    // Un PDF compartido desde WhatsApp o Gmail trae aquí: se importa al abrir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _importarCompartido());
  }

  void _importarCompartido() {
    final pdf = ref.read(pdfPorImportarProvider);
    if (pdf == null) return;
    ref.read(pdfPorImportarProvider.notifier).state = null;
    _importar(pdf);
  }

  Future<void> _elegirPdf() async {
    final bytes = await elegirPdf();
    if (bytes != null) await _importar(bytes);
  }

  Future<void> _importar(Uint8List pdf) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() {
      _importando = true;
      _resultado = null;
    });
    try {
      final r = await ref
          .read(repositorioDetectadosProvider)
          .importarExtracto(pdf);
      if (!mounted) return;
      final rango = r.desde != null && r.hasta != null
          ? 'Del ${Formato.fechaCorta(r.desde!)} al ${Formato.fechaCorta(r.hasta!)}: '
          : '';
      setState(() => _resultado = '$rango${r.frase}.');
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  Future<void> _aceptarListos(List<Detectado> listos) async {
    final mensajero = ScaffoldMessenger.of(context);
    final repositorio = ref.read(repositorioDetectadosProvider);
    setState(() => _aceptando = true);
    var hechos = 0;
    try {
      for (final d in listos) {
        await repositorio.aceptar(
          d.id,
          destino: d.sugerenciaDestino!,
          descripcion: d.sugerenciaNombre,
          categoria: d.categoriaSugerida,
          tipoIngreso: d.tipoIngresoSugerido,
          deudaId: d.sugerenciaObjetivo,
        );
        hechos++;
      }
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            hechos == 1 ? 'Quedó registrado 1' : 'Quedaron registrados $hechos',
          ),
        ),
      );
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('Se registraron $hechos. ${e.mensaje}')),
      );
    } finally {
      if (mounted) setState(() => _aceptando = false);
      await refrescarSecciones(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si llega otro PDF compartido con la pantalla ya abierta.
    ref.listen(pdfPorImportarProvider, (_, pdf) {
      if (pdf != null) _importarCompartido();
    });
    final datos = ref.watch(detectadosProvider);
    final ancho = Pantalla.esEscritorio(context) ? 680.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Por revisar'),
        actions: [
          IconButton(
            tooltip: 'Registro automático',
            onPressed: () => context.push(Rutas.registroAutomatico),
            icon: const Icon(Iconos.ajustes),
          ),
          IconButton(
            tooltip: 'Importar extracto en PDF',
            onPressed: _importando ? null : _elegirPdf,
            icon: const Icon(Iconos.recibo),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(detectadosProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Espacio.lateral,
                Espacio.s,
                Espacio.lateral,
                40,
              ),
              children: [
                if (_importando)
                  const Padding(
                    padding: EdgeInsets.only(bottom: Espacio.l),
                    child: CajaAviso(
                      tono: Tono.suave,
                      icono: Iconos.recibo,
                      texto: TextSpan(
                        text:
                            'Leyendo el extracto y cruzándolo con lo apuntado…',
                      ),
                    ),
                  ),
                if (_resultado != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Espacio.l),
                    child: CajaAviso(
                      tono: Tono.positivo,
                      icono: Iconos.listo,
                      texto: TextSpan(text: _resultado),
                    ),
                  ),
                ...datos.when(
                  skipLoadingOnRefresh: true,
                  loading: () => const [
                    Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [
                    EstadoVacio(
                      icono: Iconos.sinConexion,
                      titulo: 'No se pudo cargar',
                      texto: e is ErrorApi ? e.mensaje : 'Inténtalo de nuevo',
                      accion: 'Reintentar',
                      alTocarAccion: () => ref.invalidate(detectadosProvider),
                    ),
                  ],
                  data: (lista) => lista.isEmpty
                      ? [
                          EstadoVacio(
                            icono: Iconos.listo,
                            titulo: 'Nada por revisar',
                            texto:
                                'Aquí llegan los movimientos que avisa el banco. '
                                'Para traer los que faltan, importa el PDF '
                                '«Movimientos» de Bancolombia.',
                            accion: 'Importar extracto',
                            alTocarAccion: _importando ? null : _elegirPdf,
                          ),
                        ]
                      : _contenido(context, lista),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, List<Detectado> lista) {
    final listos = lista.where((d) => d.listoParaAceptar).toList();
    final textos = Theme.of(context).textTheme;
    final c = context.colores;

    // Por día, del más reciente al más viejo.
    final dias = <DateTime, List<Detectado>>{};
    for (final d in lista) {
      dias.putIfAbsent(d.fecha, () => []).add(d);
    }

    return [
      Text(
        lista.length == 1
            ? '1 movimiento del banco que no está en la app.'
            : '${lista.length} movimientos del banco que no están en la app.',
        style: textos.bodyMedium?.copyWith(color: c.tinta2),
      ),
      if (listos.isNotEmpty) ...[
        const SizedBox(height: Espacio.m),
        FilledButton.icon(
          onPressed: _aceptando ? null : () => _aceptarListos(listos),
          icon: const Icon(Iconos.listo),
          label: Text(
            listos.length == 1
                ? 'Registrar el que ya sé cómo'
                : 'Registrar los ${listos.length} que ya sé cómo',
          ),
        ),
      ],
      for (final dia in dias.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(
            Formato.fecha(dia.key),
            style: textos.labelLarge?.copyWith(color: c.tinta2),
          ),
        ),
        Panel.lista(
          filas: [for (final d in dia.value) _FilaDetectado(detectado: d)],
        ),
      ],
    ];
  }
}

class _FilaDetectado extends StatelessWidget {
  const _FilaDetectado({required this.detectado});

  final Detectado detectado;

  @override
  Widget build(BuildContext context) {
    final d = detectado;
    final hora = d.hora?.substring(0, 5);
    return Fila(
      inicio: IconoCaja(d.entra ? Iconos.entro : Iconos.salio),
      titulo: d.nombreSugerido,
      etiqueta: d.listoParaAceptar
          ? Etiqueta(d.sugerenciaDestino!.etiqueta, tono: Tono.positivo)
          : null,
      // La referencia (celular, llave o cuenta) es lo que dice de quién es un «Nequi».
      subtitulo: [
        d.etiquetaClase,
        ?d.referencia,
        d.etiquetaOrigen,
        ?hora,
      ].join(' · '),
      importe: d.monto,
      importeConSigno: true,
      alTocar: () => HojaRevisar.abrir(context, d),
    );
  }
}
