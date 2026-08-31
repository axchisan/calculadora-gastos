import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configuracion.dart';
import '../../../core/version.dart';

/// Apartado con la versión instalada.
///
/// Está en «Mi cuenta» y no en una pantalla propia porque es información que se consulta muy de
/// vez en cuando: al comprobar si el teléfono ya tiene la última compilación, o al reportar algo
/// que no cuadra.
class TarjetaVersion extends ConsumerWidget {
  const TarjetaVersion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(versionProvider);
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/icono/icono.png',
                width: 40,
                height: 40,
                // Si el icono no estuviera empaquetado, mejor un hueco que una pantalla roja.
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.info_outline, size: 40),
              ),
            ),
            title: Text(version.valueOrNull?.nombre ?? 'Mis gastos'),
            subtitle: Text(switch (version) {
              AsyncData(:final value) => 'Versión ${value.version}',
              AsyncError() => 'No se pudo leer la versión',
              _ => 'Leyendo la versión…',
            }),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // El número de compilación va con su etiqueta y no entre paréntesis tras la versión:
          // suelto, un 2013 se lee como un año. En Android además no coincide con el del
          // pubspec, porque al compilar por arquitectura Flutter le antepone la suya.
          if (version.valueOrNull?.compilacion.isNotEmpty ?? false)
            _Dato(
              etiqueta: 'Compilación',
              valor: version.requireValue.compilacion,
              color: esquema.onSurfaceVariant,
            ),
          _Dato(
            etiqueta: 'Plataforma',
            valor: VersionApp.plataforma,
            color: esquema.onSurfaceVariant,
          ),
          _Dato(
            etiqueta: 'Servidor',
            valor: _servidor,
            color: esquema.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// La dirección de la API sin el esquema, que no aporta nada al leerla.
  String get _servidor {
    final url = Uri.tryParse(Configuracion.urlApi);
    if (url == null || url.host.isEmpty) return Configuracion.urlApi;
    return url.hasPort ? '${url.host}:${url.port}' : url.host;
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo?.copyWith(color: color)),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: estilo?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
