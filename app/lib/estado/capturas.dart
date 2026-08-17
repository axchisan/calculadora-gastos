import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/capturas_android.dart';
import '../dominio/captura_pago.dart';
import '../dominio/modelos.dart';
import 'compras.dart';

final capturasAndroidProvider = Provider<CapturasAndroid>(
  (ref) => const CapturasAndroid(),
);

/// Si la plataforma admite capturar pagos del teléfono.
final capturaDisponibleProvider = Provider<bool>(
  (ref) => ref.watch(capturasAndroidProvider).disponible,
);

/// Si el usuario ya concedió el acceso a las notificaciones.
final permisoCapturaProvider = FutureProvider<bool>(
  (ref) => ref.watch(capturasAndroidProvider).permisoConcedido(),
);

/// Un pago capturado esperando a que el usuario lo confirme.
///
/// No se registra solo. Un importe mal reconocido metido directamente en el presupuesto haría
/// perder la confianza en las cifras, que es lo único que esta aplicación tiene que ofrecer.
/// Con la bandeja, confirmar cuesta un toque y el usuario ve lo que entra.
class PagoPendiente {
  const PagoPendiente({required this.ids, required this.pago, this.tarjeta});

  /// Identificadores de todas las notificaciones que describen esta misma compra.
  ///
  /// Son varias porque al pagar llegan dos avisos, el de la billetera y el del banco, y las
  /// dos hay que descartarlas juntas al resolverla.
  final List<String> ids;

  final PagoDetectado pago;

  /// La tarjeta reconocida, o null si no se pudo identificar.
  final Tarjeta? tarjeta;

  /// Con qué se pagó, deducido de la tarjeta.
  ///
  /// Sin tarjeta reconocida se propone débito y no efectivo: la captura viene de un pago con
  /// el teléfono, así que de efectivo no fue.
  MedioPago get medioSugerido =>
      tarjeta == null ? MedioPago.debito : tarjeta!.tipo.medioPago;

  /// Nombre para la compra: el comercio, o el importe si no se reconoció.
  String get descripcionSugerida =>
      pago.comercio ?? 'Pago con ${pago.fuente.etiqueta}';

  bool get faltaIdentificarTarjeta =>
      tarjeta == null && (pago.apodoTarjeta != null || pago.ultimos4 != null);
}

/// Los pagos capturados por el teléfono, listos para confirmar.
final pagosPendientesProvider = FutureProvider<List<PagoPendiente>>((
  ref,
) async {
  final capturas = await ref.watch(capturasAndroidProvider).pendientes();
  if (capturas.isEmpty) return const [];

  final tarjetas = await ref.watch(tarjetasProvider.future);

  // Se reconoce cada notificación por separado y después se juntan las que describen la misma
  // compra: al pagar llegan dos, una de la billetera y otra del banco.
  final reconocidos = <(String, PagoDetectado)>[];
  for (final captura in capturas) {
    final pago = LectorDePagos.leer(captura);
    if (pago != null) reconocidos.add((captura.id, pago));
  }

  final agrupados = <PagoPendiente>[];
  for (final (id, pago) in reconocidos) {
    final indice = agrupados.indexWhere((p) => p.pago.esLaMismaCompraQue(pago));

    if (indice == -1) {
      agrupados.add(
        PagoPendiente(ids: [id], pago: pago, tarjeta: _buscar(tarjetas, pago)),
      );
    } else {
      final fusionado = agrupados[indice].pago.fusionarCon(pago);
      agrupados[indice] = PagoPendiente(
        ids: [...agrupados[indice].ids, id],
        pago: fusionado,
        tarjeta: _buscar(tarjetas, fusionado),
      );
    }
  }

  // De la más reciente a la más antigua, que es como se van a resolver.
  agrupados.sort((a, b) => b.pago.instante.compareTo(a.pago.instante));
  return agrupados;
});

Tarjeta? _buscar(List<Tarjeta> tarjetas, PagoDetectado pago) {
  for (final tarjeta in tarjetas) {
    if (tarjeta.reconoce(apodo: pago.apodoTarjeta, ultimos4: pago.ultimos4)) {
      return tarjeta;
    }
  }
  return null;
}

/// Quita de la bandeja los pagos ya resueltos, se hayan registrado o descartado.
final descartarCapturasProvider = Provider<Future<void> Function(List<String>)>(
  (ref) {
    return (ids) async {
      await ref.read(capturasAndroidProvider).descartar(ids);
      ref.invalidate(pagosPendientesProvider);
    };
  },
);
