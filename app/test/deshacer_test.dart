import 'package:calculadora_gastos/ui/comun/deshacer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pantalla mínima con un botón que borra el elemento «a» con opción de deshacer.
class _Banco extends ConsumerWidget {
  const _Banco({required this.alBorrar});

  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocultos = ref.watch(ocultosProvider);
    return Scaffold(
      body: Column(
        children: [
          if (!ocultos.contains('a')) const Text('Elemento a'),
          Builder(
            builder: (contexto) => TextButton(
              onPressed: () => borrarConDeshacer(
                contexto,
                ref,
                id: 'a',
                mensaje: 'Borraste a',
                borrar: () async => alBorrar(),
              ),
              child: const Text('Borrar'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _montar(WidgetTester tester, VoidCallback alBorrar) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: _Banco(alBorrar: alBorrar)),
      ),
    );

void main() {
  testWidgets('esconde al instante y no borra hasta que vence el aviso', (
    tester,
  ) async {
    var borrados = 0;
    await _montar(tester, () => borrados++);

    await tester.tap(find.text('Borrar'));
    await tester.pump();

    expect(find.text('Elemento a'), findsNothing);
    expect(find.text('Deshacer'), findsOneWidget);
    expect(borrados, 0);

    // El tiempo del aviso empieza a contar cuando termina su animación de entrada.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(duracionDeshacer);
    await tester.pumpAndSettle();

    expect(borrados, 1);
  });

  testWidgets('deshacer devuelve el elemento y no lo borra', (tester) async {
    var borrados = 0;
    await _montar(tester, () => borrados++);

    await tester.tap(find.text('Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(find.text('Elemento a'), findsOneWidget);
    expect(borrados, 0);

    // Aunque pase el tiempo, ya no se borra.
    await tester.pump(duracionDeshacer * 2);
    await tester.pumpAndSettle();
    expect(borrados, 0);
  });

  testWidgets('borrar otra cosa confirma el borrado anterior', (tester) async {
    var borrados = 0;
    await _montar(tester, () => borrados++);

    await tester.tap(find.text('Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Un segundo borrado cierra el primer aviso, y ese primer borrado se aplica.
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(borrados, 1);
  });
}
