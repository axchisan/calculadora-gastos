import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/tema.dart';
import '../../dominio/modelos.dart';
import '../../estado/modulos.dart';
import '../catalogo/pantalla_catalogo.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';
import '../comun/selector_tema.dart';
import '../diario/widgets/tarjetas_gestion.dart';

/// Ajustes: el tema, las secciones opcionales y lo que se configura una vez y luego casi no se
/// toca. Se entra desde el avatar de Inicio.
class PantallaAjustes extends ConsumerWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulos = ref.watch(modulosProvider);
    final c = context.colores;
    final ancho = Pantalla.esEscritorio(context) ? 640.0 : double.infinity;

    Widget ir(
      IconData icono,
      String titulo,
      VoidCallback alTocar, {
      String? sub,
    }) => Fila(
      inicio: IconoCaja(icono),
      titulo: titulo,
      subtitulo: sub,
      final_: Icon(Iconos.entrar, color: c.tinta3, size: 20),
      alTocar: alTocar,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lateral,
              0,
              Espacio.lateral,
              Espacio.seccion,
            ),
            children: [
              const Seccion(
                titulo: 'Tema',
                arriba: Espacio.s,
                child: SelectorTema(),
              ),
              Seccion(
                titulo: 'Secciones opcionales',
                child: Panel.lista(
                  filas: [
                    for (final m in Modulo.values)
                      Fila(
                        inicio: IconoCaja(
                          m == Modulo.ahorro
                              ? Iconos.ahorro
                              : Iconos.deCategoria(CategoriaGasto.transporte),
                        ),
                        titulo: m.nombre,
                        subtitulo: m.descripcion,
                        final_: Switch(
                          value: modulos.contains(m),
                          onChanged: (v) => ref
                              .read(modulosProvider.notifier)
                              .cambiar(m, visible: v),
                        ),
                        alTocar: () => ref
                            .read(modulosProvider.notifier)
                            .cambiar(m, visible: !modulos.contains(m)),
                      ),
                  ],
                ),
              ),
              Seccion(
                titulo: 'Tu información',
                child: Panel.lista(
                  filas: [
                    ir(
                      Iconos.banco,
                      'Mis cuentas y efectivo',
                      () => context.push(Rutas.cuentas),
                    ),
                    ir(
                      Iconos.dolar,
                      'Mi sueldo',
                      () => context.push(Rutas.sueldo),
                    ),
                    ir(
                      Iconos.recibo,
                      'Gastos fijos',
                      () => context.push(Rutas.plantillas),
                      sub: 'Los que se copian a cada mes nuevo',
                    ),
                    ir(
                      Iconos.tarjeta,
                      'Tarjetas',
                      () => showModalBottomSheet<void>(
                        context: context,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        builder: (_) => const GestionTarjetas(),
                      ),
                      sub: 'Corte, pago y detección de compras',
                    ),
                    ir(
                      Iconos.familia,
                      'Mi cuenta',
                      () => context.push(Rutas.cuenta),
                      sub: 'Nombre, correo, contraseña y cerrar sesión',
                    ),
                    if (PantallaCatalogo.habilitado)
                      ir(
                        Iconos.ajustes,
                        'Componentes del rediseño',
                        () => context.push(Rutas.catalogo),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
