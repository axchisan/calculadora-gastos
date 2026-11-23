import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/autenticacion.dart';
import '../../estado/detectados.dart';

/// Recoge el extracto en PDF compartido desde otra aplicación (WhatsApp, Gmail, Archivos) y
/// lleva a «Por revisar», que lo importa. Si la sesión aún se está comprobando, espera a que
/// esté abierta para no perder el salto.
class RecepcionDeExtractos extends ConsumerStatefulWidget {
  const RecepcionDeExtractos({required this.hijo, required this.ir, super.key});

  final Widget hijo;

  /// Abre la pantalla «Por revisar».
  final VoidCallback ir;

  @override
  ConsumerState<RecepcionDeExtractos> createState() => _EstadoRecepcion();
}

class _EstadoRecepcion extends ConsumerState<RecepcionDeExtractos>
    with WidgetsBindingObserver {
  bool _saltoPendiente = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(extractosCompartidosProvider).alRecibir(_recoger);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoger());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _recoger();
  }

  Future<void> _recoger() async {
    final pdf = await ref.read(extractosCompartidosProvider).tomar();
    if (pdf == null || !mounted) return;
    ref.read(pdfPorImportarProvider.notifier).state = pdf;
    _saltoPendiente = true;
    _saltarSiSePuede();
  }

  void _saltarSiSePuede() {
    if (!_saltoPendiente || ref.read(sesionProvider) is! SesionAbierta) return;
    _saltoPendiente = false;
    // Tras el fotograma: el enrutador puede estar aún saliendo de la pantalla de carga.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.ir());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sesionProvider, (_, _) => _saltarSiSePuede());
    return widget.hijo;
  }
}
