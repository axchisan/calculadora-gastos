import 'package:flutter/material.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../dominio/modelos.dart';
import '../../../estado/modo_vista.dart';

/// Resumen económico del mes, en cualquiera de los dos modos de lectura.
///
/// En **real** manda lo pagado: responde a «¿cuánto tengo ahora mismo?». En **estimación**
/// manda lo comprometido: «¿cuánto de mi sueldo ya tiene destino?». La segunda es la única
/// útil para un mes que aún no ha empezado, donde no hay ningún pago hecho y todas las cifras
/// de lo pagado son cero.
class TarjetaSaldo extends StatelessWidget {
  const TarjetaSaldo({
    required this.resumen,
    required this.modo,
    this.alEditarIngreso,
    this.alAlternarModo,
    super.key,
  });

  final ResumenMensual resumen;
  final ModoVista modo;

  /// Permite ajustar el sueldo tocando la cifra de ingreso. Nulo si el mes está cerrado.
  final VoidCallback? alEditarIngreso;

  final VoidCallback? alAlternarModo;

  bool get _esEstimacion => modo == ModoVista.estimacion;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    final cifraPrincipal = _esEstimacion
        ? resumen.saldoProyectado
        : resumen.disponibleHoy;
    final etiquetaPrincipal = _esEstimacion
        ? 'Te quedaría libre'
        : 'Disponible hoy';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    etiquetaPrincipal,
                    style: textos.labelLarge?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                if (resumen.cerrado)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: const Text('Cerrado'),
                      visualDensity: VisualDensity.compact,
                      labelStyle: textos.labelSmall,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                if (alAlternarModo != null)
                  _BotonModo(modo: modo, alPulsar: alAlternarModo!),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              Formato.dinero(cifraPrincipal),
              style: textos.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Tema.paraSaldo(cifraPrincipal),
              ),
            ),

            const SizedBox(height: 20),
            if (_esEstimacion)
              _BarraCompromiso(resumen: resumen)
            else
              _BarraPagos(resumen: resumen),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: alEditarIngreso,
                    borderRadius: BorderRadius.circular(8),
                    child: _Cifra(
                      etiqueta: 'Ingreso',
                      valor: _esEstimacion
                          ? resumen.ingresoProyectado
                          : resumen.ingresoTotal,
                      icono: Icons.arrow_downward,
                      color: Tema.positivo,
                      editable: alEditarIngreso != null,
                    ),
                  ),
                ),
                Expanded(
                  child: _Cifra(
                    etiqueta: _esEstimacion ? 'Comprometido' : 'Gastos',
                    valor: _esEstimacion
                        ? resumen.comprometido
                        : resumen.gastoTotal,
                    icono: Icons.arrow_upward,
                    color: Tema.pendiente,
                  ),
                ),
                Expanded(
                  child: _Cifra(
                    etiqueta: _esEstimacion ? 'Sin asignar' : 'Al cerrar',
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

/// Botón que alterna entre ver lo pagado y ver lo comprometido.
class _BotonModo extends StatelessWidget {
  const _BotonModo({required this.modo, required this.alPulsar});

  final ModoVista modo;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final esEstimacion = modo == ModoVista.estimacion;

    return Tooltip(
      message: 'Ver ${modo.contrario.descripcion.toLowerCase()}',
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: esEstimacion
                ? esquema.primaryContainer
                : esquema.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                esEstimacion ? Icons.query_stats : Icons.receipt_long_outlined,
                size: 14,
                color: esEstimacion
                    ? esquema.onPrimaryContainer
                    : esquema.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                modo.etiqueta,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: esEstimacion
                      ? esquema.onPrimaryContainer
                      : esquema.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuánto del mes se lleva pagado.
class _BarraPagos extends StatelessWidget {
  const _BarraPagos({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final total = resumen.gastoTotal;
    final proporcion = total == 0
        ? 0.0
        : (resumen.gastoPagado / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Barra(proporcion: proporcion, color: Tema.positivo),
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

/// Cuánto del sueldo ya tiene destino, esté pagado o no.
class _BarraCompromiso extends StatelessWidget {
  const _BarraCompromiso({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final excedido = resumen.estaSobrecomprometido;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Barra(
          proporcion: resumen.proporcionComprometida,
          color: excedido ? Tema.negativo : esquema.primary,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text(
                '${resumen.porcentajeComprometido.toStringAsFixed(0)}% del sueldo con destino',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: excedido ? Tema.negativo : null,
                  fontWeight: excedido ? FontWeight.w600 : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Text(
              Formato.dinero(resumen.comprometido),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
        if (excedido) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.warning_amber, size: 15, color: Tema.negativo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tienes comprometido más de lo que esperas ingresar.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Tema.negativo),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.proporcion, required this.color});

  final double proporcion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            FractionallySizedBox(
              widthFactor: proporcion,
              child: Container(color: color),
            ),
          ],
        ),
      ),
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
