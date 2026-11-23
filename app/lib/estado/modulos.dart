import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cache_local.dart';
import 'proveedores.dart';

/// Secciones que no todo el mundo usa y que por eso empiezan escondidas.
enum Modulo {
  ahorro('ahorro', 'Metas de ahorro', 'Para cuando empieces a guardar'),
  transporte('transporte', 'Transporte', 'Calendario de pasajes por días');

  const Modulo(this.codigo, this.nombre, this.descripcion);

  final String codigo;
  final String nombre;
  final String descripcion;
}

/// Las secciones opcionales que se ven. Se encienden y apagan en Ajustes.
class ControladorModulos extends StateNotifier<Set<Modulo>> {
  ControladorModulos(this._cache)
    : super({
        for (final m in Modulo.values)
          if (_cache.leerModulo(m.codigo)) m,
      });

  final CacheLocal _cache;

  Future<void> cambiar(Modulo modulo, {required bool visible}) async {
    state = visible ? {...state, modulo} : ({...state}..remove(modulo));
    await _cache.guardarModulo(modulo.codigo, visible: visible);
  }
}

final modulosProvider = StateNotifierProvider<ControladorModulos, Set<Modulo>>(
  (ref) => ControladorModulos(ref.watch(cacheProvider)),
);
