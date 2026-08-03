import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'datos/cache_local.dart';
import 'estado/proveedores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga los nombres de meses y días en español; sin esto, las fechas saldrían en inglés.
  await initializeDateFormatting('es_CO');

  // El caché se abre antes de arrancar para que la primera pantalla pueda pintar datos
  // mientras llega la respuesta del servidor.
  final cache = await CacheLocal.abrir();

  runApp(
    ProviderScope(
      overrides: [cacheProvider.overrideWithValue(cache)],
      child: const AplicacionGastos(),
    ),
  );
}
