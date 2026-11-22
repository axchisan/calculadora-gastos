import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../dominio/modelos.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';
import '../comun/selector_tema.dart';

/// Catálogo de las piezas del rediseño, con datos de ejemplo.
///
/// Sirve para revisar el sistema de diseño de un vistazo, en claro y en oscuro, sin depender de
/// que una pantalla real tenga datos de cada tipo. Solo se incluye al compilar con
/// `--dart-define=CATALOGO=true`.
class PantallaCatalogo extends StatelessWidget {
  const PantallaCatalogo({super.key});

  static const bool habilitado = bool.fromEnvironment('CATALOGO');

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Componentes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Espacio.lateral,
          8,
          Espacio.lateral,
          40,
        ),
        children: [
          const SelectorTema(),
          const SizedBox(height: Espacio.seccion),
          CifraPrincipal(
            etiqueta: 'Tienes hoy',
            valor: 48250.37,
            debajo: [
              Etiqueta(
                'Cuadra con tus bancos',
                tono: Tono.positivo,
                icono: Iconos.listo,
                grande: true,
                alTocar: () {},
              ),
              const Etiqueta(
                'Faltan 5 días',
                icono: Iconos.calendario,
                grande: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const CajaAviso(
            icono: Iconos.atencion,
            texto: TextSpan(
              children: [
                TextSpan(text: 'Te falta pagar el '),
                TextSpan(
                  text: 'celular (\$100.000)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '. Con lo que tienes, te faltarían \$18.500.'),
              ],
            ),
          ),
          Seccion(
            titulo: 'Próximos pagos',
            accion: '30 días',
            child: Panel.lista(
              filas: const [
                Fila(
                  inicio: FechaCorta(dia: '1–7', mes: 'dic'),
                  titulo: 'Sueldo',
                  subtitulo: '500 USD',
                  importe: 1250000,
                  importeConSigno: true,
                  debajoDelImporte: 'estimado',
                ),
                Fila(
                  inicio: FechaCorta(dia: '4', mes: 'dic'),
                  titulo: 'Tarjeta de crédito',
                  subtitulo: 'Pago mínimo',
                  etiqueta: Etiqueta('Mismo día', tono: Tono.aviso),
                  importe: -95000,
                ),
              ],
            ),
          ),
          Seccion(
            titulo: 'Movimientos',
            child: Panel.lista(
              filas: [
                Fila(
                  inicio: IconoCaja(
                    Iconos.deCategoria(CategoriaGasto.servicios),
                  ),
                  titulo: 'Wifi de la casa',
                  subtitulo: 'Servicios · Banco',
                  etiqueta: const Etiqueta('Fijo'),
                  importe: -40000,
                  alTocar: () {},
                ),
                Fila(
                  inicio: const IconoCaja(Iconos.prestamo),
                  titulo: 'Préstamo',
                  subtitulo: 'Préstamo · Banco',
                  etiqueta: const Etiqueta('Préstamo'),
                  importe: 85000,
                  importeConSigno: true,
                  alTocar: () {},
                ),
                Fila(
                  inicio: const IconoCaja(Iconos.intereses),
                  titulo: 'Intereses del banco',
                  importe: 0.78,
                  importeConSigno: true,
                ),
                Fila(
                  inicio: const IconoCaja(Iconos.billetera),
                  titulo: 'Celular',
                  subtitulo: 'Por pagar',
                  final_: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Pagar'),
                  ),
                ),
              ],
            ),
          ),
          Seccion(
            titulo: 'Este mes',
            child: Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entró', style: textos.labelMedium),
                        const SizedBox(height: 4),
                        Importe(
                          980000,
                          colorear: false,
                          estilo: textos.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Salió', style: textos.labelMedium),
                        const SizedBox(height: 4),
                        Importe(
                          640000,
                          colorear: false,
                          estilo: textos.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Seccion(
            titulo: 'Etiquetas y avisos',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in Tono.values)
                  Etiqueta(t.name, tono: t, grande: true),
                for (final t in Tono.values) Etiqueta(t.name, tono: t),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final t in [Tono.positivo, Tono.negativo, Tono.suave]) ...[
            CajaAviso(
              texto: TextSpan(text: 'Aviso en tono ${t.name}.'),
              tono: t,
            ),
            const SizedBox(height: 8),
          ],
          Seccion(
            titulo: 'Botones',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Guardar')),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Editar'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => abrirHoja<void>(
                    context,
                    titulo: 'Hoja inferior',
                    subtitulo: 'Así se ven los detalles y formularios.',
                    contenido: (_) => const TextField(
                      decoration: InputDecoration(labelText: '¿Qué fue?'),
                    ),
                  ),
                  child: const Text('Abrir una hoja'),
                ),
              ],
            ),
          ),
          Seccion(
            titulo: 'Categorías',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in CategoriaGasto.values)
                  Chip(
                    avatar: Icon(
                      Iconos.deCategoria(cat),
                      size: 16,
                      color: c.tinta2,
                    ),
                    label: Text(cat.etiqueta),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Espacio.seccion),
          const EstadoVacio(
            icono: Iconos.meta,
            titulo: 'Sin metas de ahorro',
            texto: 'Crea una meta y la app te propone cuánto apartar cada mes.',
            accion: 'Crear una meta',
          ),
        ],
      ),
    );
  }
}
