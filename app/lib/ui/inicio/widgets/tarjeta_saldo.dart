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
        ? resumen.saldoTrasCuotas
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

            // La barra solo cuenta gastos, así que un abono a una deuda o un aporte al ahorro
            // reducían el disponible sin dejar rastro de a dónde habían ido.
            if (_esEstimacion)
              _DetalleCompromisos(resumen: resumen)
            else
              _DetalleSalidas(resumen: resumen),

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
                        ? resumen.comprometidoConCuotas
                        : resumen.gastoTotal,
                    icono: Icons.arrow_upward,
                    color: Tema.pendiente,
                  ),
                ),
                Expanded(
                  child: _Cifra(
                    etiqueta: _esEstimacion ? 'Sin asignar' : 'Al cerrar',
                    valor: _esEstimacion
                        ? resumen.saldoTrasCuotas
                        : resumen.saldoProyectado,
                    icono: Icons.flag_outlined,
                    color: Tema.paraSaldo(
                      _esEstimacion
                          ? resumen.saldoTrasCuotas
                          : resumen.saldoProyectado,
                    ),
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

/// Cuánto del mes se lleva cubierto.
///
/// Cuenta todo lo que hay que pagar, no solo los gastos: una cuota de deuda sale del bolsillo
/// igual que el arriendo, y dejarla fuera daba un «falta» que se quedaba corto.
class _BarraPagos extends StatelessWidget {
  const _BarraPagos({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Barra(proporcion: resumen.proporcionCubierta, color: Tema.positivo),
        const SizedBox(height: 8),
        Row(
          children: [
            _Punto(
              color: Tema.positivo,
              texto: 'Pagado ${Formato.dinero(resumen.salidaReal)}',
            ),
            const Spacer(),
            _Punto(
              color: esquema.surfaceContainerHighest,
              texto: 'Falta ${Formato.dinero(resumen.pendienteTotal)}',
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

/// Desglose del dinero que ya salió este mes.
class _DetalleSalidas extends StatelessWidget {
  const _DetalleSalidas({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    final hayAlgoQueDesglosar =
        resumen.abonosDeuda > 0 ||
        resumen.aporteAhorro > 0 ||
        resumen.cuotasDeudaPendientes > 0 ||
        resumen.comprasDelMes > 0 ||
        resumen.cortesTarjetaPendientes > 0 ||
        resumen.cuotasCreditoPendientes > 0;
    if (!hayAlgoQueDesglosar) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _Linea(
            icono: Icons.receipt_long_outlined,
            etiqueta: 'Gastos por pagar',
            valor: resumen.gastoPendiente,
            color: Tema.pendiente,
          ),
          if (resumen.cuotasDeudaPendientes > 0)
            _Linea(
              icono: Icons.event_repeat,
              etiqueta: 'Cuotas de deuda por pagar',
              valor: resumen.cuotasDeudaPendientes,
              color: Tema.negativo,
            ),
          if (resumen.cortesTarjetaPendientes > 0)
            _Linea(
              icono: Icons.credit_card,
              etiqueta: 'Corte de tarjeta por pagar',
              valor: resumen.cortesTarjetaPendientes,
              color: Tema.negativo,
            ),
          if (resumen.cuotasCreditoPendientes > 0)
            _Linea(
              icono: Icons.account_balance,
              etiqueta: 'Cuota de crédito por pagar',
              valor: resumen.cuotasCreditoPendientes,
              color: Tema.negativo,
            ),
          if (resumen.comprasInmediatas > 0)
            _Linea(
              icono: Icons.shopping_basket_outlined,
              etiqueta: 'Gastado en el día a día',
              valor: resumen.comprasInmediatas,
              color: Tema.positivo,
            ),
          if (resumen.abonosDeuda > 0)
            _Linea(
              icono: Icons.credit_card,
              etiqueta: 'Ya abonado a deudas',
              valor: resumen.abonosDeuda,
              color: Tema.positivo,
            ),
          if (resumen.aporteAhorro > 0)
            _Linea(
              icono: Icons.savings_outlined,
              etiqueta: 'Guardado en metas',
              valor: resumen.aporteAhorro,
              color: Tema.positivo,
            ),
          const Divider(height: 16),
          _Linea(
            icono: Icons.pending_actions,
            etiqueta: 'Te falta pagar',
            valor: resumen.pendienteTotal,
            color: Theme.of(context).colorScheme.onSurface,
            resaltado: true,
          ),

          // Va después del total y separado a propósito: no es dinero que falte este mes, pero
          // ya está gastado y llegará como corte más adelante. Sumarlo arriba mentiría; no
          // mostrarlo también.
          if (resumen.tieneCreditoPorVencer) ...[
            const SizedBox(height: 10),
            _AvisoCredito(monto: resumen.comprasACredito),
          ],
        ],
      ),
    );
  }
}

/// Recordatorio de lo que se cargó a crédito este mes y se pagará más adelante.
class _AvisoCredito extends StatelessWidget {
  const _AvisoCredito({required this.monto});

  final double monto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.schedule,
          size: 15,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Además llevas ${Formato.dinero(monto)} a crédito este mes. '
            'No sale ahora: llega con el corte de la tarjeta.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Desglose de lo que ya tiene destino, cuotas de deuda incluidas.
class _DetalleCompromisos extends StatelessWidget {
  const _DetalleCompromisos({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final hayCuotas = resumen.cuotasDeudaPendientes > 0;
    final faltanCuotas = resumen.deudasSinCuota > 0;
    final hayTarjetas = resumen.cortesTarjetaPendientes > 0;
    final hayCompras = resumen.comprasInmediatas > 0;
    final hayCredito = resumen.cuotasCreditoPendientes > 0;

    if (!hayCuotas &&
        !faltanCuotas &&
        !hayTarjetas &&
        !hayCompras &&
        !hayCredito &&
        resumen.aporteAhorro == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Linea(
            icono: Icons.receipt_long_outlined,
            etiqueta: 'Gastos del mes',
            valor: resumen.gastoTotal,
            color: Tema.pendiente,
          ),
          if (hayCompras)
            _Linea(
              icono: Icons.shopping_basket_outlined,
              etiqueta: 'Día a día',
              valor: resumen.comprasInmediatas,
              color: Tema.pendiente,
            ),
          if (hayTarjetas)
            _Linea(
              icono: Icons.credit_card,
              etiqueta: 'Corte de tarjeta',
              valor: resumen.cortesTarjetaPendientes,
              color: Tema.negativo,
            ),
          if (hayCredito)
            _Linea(
              icono: Icons.account_balance,
              etiqueta: 'Cuota de crédito',
              valor: resumen.cuotasCreditoPendientes,
              color: Tema.negativo,
            ),
          if (resumen.abonosDeuda > 0)
            _Linea(
              icono: Icons.credit_card,
              etiqueta: 'Ya abonado a deudas',
              valor: resumen.abonosDeuda,
              color: Tema.negativo,
            ),
          if (hayCuotas)
            _Linea(
              icono: Icons.event_repeat,
              etiqueta: 'Cuotas de deuda por pagar',
              valor: resumen.cuotasDeudaPendientes,
              color: Tema.negativo,
            ),
          if (resumen.aporteAhorro > 0)
            _Linea(
              icono: Icons.savings_outlined,
              etiqueta: 'Ahorro',
              valor: resumen.aporteAhorro,
              color: Tema.positivo,
            ),

          if (faltanCuotas) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 15, color: Tema.pendiente),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    resumen.deudasSinCuota == 1
                        ? 'Tienes 1 deuda sin cuota mensual, así que no cuenta aquí. '
                              'Ponle una para verla en la estimación.'
                        : 'Tienes ${resumen.deudasSinCuota} deudas sin cuota mensual, así que '
                              'no cuentan aquí. Ponles una para verlas en la estimación.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
    this.resaltado = false,
  });

  final IconData icono;
  final String etiqueta;
  final double valor;
  final Color color;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              etiqueta,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: resaltado ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            Formato.dinero(valor),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: resaltado ? FontWeight.w700 : FontWeight.w500,
              color: resaltado ? null : color,
            ),
          ),
        ],
      ),
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
