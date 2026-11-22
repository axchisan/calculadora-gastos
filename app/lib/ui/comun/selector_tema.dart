import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/apariencia.dart';
import 'iconos.dart';

/// Claro, oscuro o según el sistema. El cambio se ve al instante y queda guardado.
class SelectorTema extends ConsumerWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(temaProvider);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Iconos.claro, size: 18),
          label: Text('Claro'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Iconos.oscuro, size: 18),
          label: Text('Oscuro'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Iconos.sistema, size: 18),
          label: Text('Sistema'),
        ),
      ],
      selected: {modo},
      onSelectionChanged: (s) =>
          ref.read(temaProvider.notifier).elegir(s.first),
    );
  }
}
