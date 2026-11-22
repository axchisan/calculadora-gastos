import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/cache_local.dart';
import 'proveedores.dart';

/// Tema elegido por el usuario.
///
/// Empieza en claro y no en «según el sistema»: el rediseño v2 se pensó en claro, y antes la
/// app seguía al teléfono sin dejar elegir, de modo que el oscuro aparecía sin pedirlo.
class ControladorTema extends StateNotifier<ThemeMode> {
  ControladorTema(this._cache) : super(_leer(_cache));

  final CacheLocal _cache;

  static const _codigos = {
    ThemeMode.light: 'claro',
    ThemeMode.dark: 'oscuro',
    ThemeMode.system: 'sistema',
  };

  static ThemeMode _leer(CacheLocal cache) {
    final guardado = cache.leerTema();
    return _codigos.entries
            .where((e) => e.value == guardado)
            .map((e) => e.key)
            .firstOrNull ??
        ThemeMode.light;
  }

  Future<void> elegir(ThemeMode modo) async {
    state = modo;
    await _cache.guardarTema(_codigos[modo]!);
  }
}

final temaProvider = StateNotifierProvider<ControladorTema, ThemeMode>(
  (ref) => ControladorTema(ref.watch(cacheProvider)),
);
