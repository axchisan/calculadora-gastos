import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga los nombres de meses y días en español; sin esto, las fechas saldrían en inglés.
  await initializeDateFormatting('es_CO');

  runApp(const ProviderScope(child: AplicacionGastos()));
}
