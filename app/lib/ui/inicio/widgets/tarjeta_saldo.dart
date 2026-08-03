import 'package:flutter/material.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../dominio/modelos.dart';

/// Resumen económico del mes.
///
/// Muestra las dos cifras a la vez a propósito. **Disponible hoy** es lo que hay en el bolsillo
/// contando solo lo ya pagado, y **al cerrar el mes** es lo que quedará cuando se pague todo lo
/// pendiente. Ver solo la primera hace creer que sobra dinero que en realidad ya está
/// comprometido.
class TarjetaSaldo extends StatelessWidget {
  const TarjetaSaldo({required this.resumen, this.alEditarIngreso, super.key});

  final ResumenMensual resumen;

  /// Permite ajustar el sueldo tocando la cifra de ingreso. Nulo si el mes está cerrado.
  final VoidCallback? alEditarIngreso;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Disponible hoy',
                  style: textos.labelLarge?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (resumen.cerrado)
                  Chip(
                    label: const Text('Mes cerrado'),
                    visualDensity: VisualDensity.compact,
                    labelStyle: textos.labelSmall,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              Formato.dinero(resumen.disponibleHoy),
              style: textos.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Tema.paraSaldo(resumen.disponibleHoy),
              ),
            ),
            const SizedBox(height: 20),

            _BarraProgreso(resumen: resumen),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: alEditarIngreso,
                    borderRadius: BorderRadius.circular(8),
                    child: _Cifra(
                      etiqueta: 'Ingreso',
                      valor: resumen.ingresoTotal,
                      icono: Icons.arrow_downward,
                      color: Tema.positivo,
                      editable: alEditarIngreso != null,
                    ),
                  ),
                ),
                Expanded(
                  child: _Cifra(
                    etiqueta: 'Gastos',
                    valor: resumen.gastoTotal,
                    icono: Icons.arrow_upward,
                    color: Tema.pendiente,
                  ),
                ),
                Expanded(
                  child: _Cifra(
                    etiqueta: 'Al cerrar',
                    valor: resumen.saldoProyectado,
                    icono: Icons.flag_outlined,
                    color: Tema.paraSaldo(resumen.saldoProyectado),
                    resaltado: true,
                  ),
                ),
              ],
            ),

            if (resumen.deudaTotal > 0 || resumen.ahorroTotal > 0) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _Cifra(
                      etiqueta: 'Ahorrado',
                      valor: resumen.ahorroTotal,
                      icono: Icons.savings_outlined,
                      color: Tema.positivo,
                    ),
                  ),
                  Expanded(
                    child: _Cifra(
                      etiqueta: 'Deuda',
                      valor: resumen.deudaTotal,
                      icono: Icons.credit_card,
                      color: Tema.negativo,
                    ),
                  ),
                  Expanded(
                    child: _Cifra(
                      etiqueta: 'Patrimonio',
                      valor: resumen.patrimonioNeto,
                      icono: Icons.account_balance_outlined,
                      color: Tema.paraSaldo(resumen.patrimonioNeto),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarraProgreso extends StatelessWidget {
  const _BarraProgreso({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final total = resumen.gastoTotal;
    final proporcionPagada = total == 0
        ? 0.0
        : (resumen.gastoPagado / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Container(color: esquema.surfaceContainerHighest),
                FractionallySizedBox(
                  widthFactor: proporcionPagada,
                  child: Container(color: Tema.positivo),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Punto(
              color: Tema.positivo,
              texto: 'Pagado ${Formato.dinero(resumen.gastoPagado)}',
            ),
            const Spacer(),
            _Punto(
              color: esquema.surfaceContainerHighest,
              texto: 'Falta ${Formato.dinero(resumen.gastoPendiente)}',
            ),
          ],
        ),
      ],
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.color,
    this.resaltado = false,
    this.editable = false,
  });

  final String etiqueta;
  final double valor;
  final IconData icono;
  final Color color;
  final bool resaltado;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                etiqueta,
                style: textos.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (editable) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.edit,
                size: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Formato.dinero(valor),
            style: textos.titleMedium?.copyWith(
              fontWeight: resaltado ? FontWeight.w700 : FontWeight.w600,
              color: resaltado ? color : null,
            ),
          ),
        ),
      ],
    );
  }
}
