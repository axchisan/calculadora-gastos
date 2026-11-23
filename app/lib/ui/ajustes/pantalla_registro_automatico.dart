import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/configuracion.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../datos/script_gmail.dart';
import '../../dominio/cuentas_y_sueldo.dart';
import '../../estado/cuentas.dart';
import '../../estado/detectados.dart';
import '../../estado/ingesta.dart';
import '../comun/componentes.dart';
import '../comun/iconos.dart';

/// «Registro automático»: que los movimientos lleguen solos a «Por revisar», por los SMS del
/// banco que recibe el teléfono y por los correos de alertas de Gmail.
class PantallaRegistroAutomatico extends ConsumerStatefulWidget {
  const PantallaRegistroAutomatico({super.key});

  @override
  ConsumerState<PantallaRegistroAutomatico> createState() =>
      _EstadoRegistroAutomatico();
}

class _EstadoRegistroAutomatico
    extends ConsumerState<PantallaRegistroAutomatico> {
  bool _trabajando = false;
  String? _aviso;

  static const _nombreTelefono = 'Teléfono';
  static const _nombreGmail = 'Gmail';

  /// Desde el último cuadre: lo anterior ya está revisado. Sin cuentas, 30 días.
  DateTime _desde() {
    final cuentas = ref.read(cuentasProvider).valueOrNull ?? const <Cuenta>[];
    final bancos = cuentas
        .where((c) => c.activa && c.tipo == TipoCuenta.banco)
        .toList();
    if (bancos.isEmpty) {
      return DateTime.now().subtract(const Duration(days: 30));
    }
    return bancos.first.saldoAl;
  }

  Future<void> _revocarLasDe(String nombre) async {
    final repo = ref.read(repositorioIngestaProvider);
    for (final c in await repo.claves()) {
      if (c.nombre == nombre) await repo.revocar(c.id);
    }
  }

  Future<void> _activarSms() async {
    final mensajero = ScaffoldMessenger.of(context);
    final sms = ref.read(ingestaSmsProvider);
    setState(() {
      _trabajando = true;
      _aviso = null;
    });
    try {
      if (!await sms.pedirPermiso()) {
        mensajero.showSnackBar(
          const SnackBar(
            content: Text('Sin el permiso de SMS no se pueden leer los avisos'),
          ),
        );
        return;
      }
      // Una sola clave por teléfono: la anterior deja de valer.
      await _revocarLasDe(_nombreTelefono);
      final (_, clave) = await ref
          .read(repositorioIngestaProvider)
          .crearClave(_nombreTelefono);
      await sms.configurar(url: Configuracion.urlApi, clave: clave);
      // Para empezar con datos: lo que llegó desde el último cuadre.
      final desde = _desde();
      final historial = await sms.historial(desde);
      var frase = 'Listo: los SMS del banco llegarán solos a «Por revisar».';
      if (historial.isNotEmpty) {
        final r = await ref.read(repositorioIngestaProvider).enviar([
          for (final s in historial) s.texto,
        ]);
        frase =
            '$frase Desde el ${Formato.fechaCorta(desde)} había '
            '${historial.length} SMS del banco: '
            '${r.nuevos == 1 ? '1 movimiento nuevo' : '${r.nuevos} movimientos nuevos'}.';
      }
      setState(() => _aviso = frase);
      ref.invalidate(detectadosProvider);
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      ref.invalidate(estadoSmsProvider);
      ref.invalidate(clavesIngestaProvider);
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _apagarSms() async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _trabajando = true);
    try {
      await ref.read(ingestaSmsProvider).configurar();
      await _revocarLasDe(_nombreTelefono);
      setState(() => _aviso = null);
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      ref.invalidate(estadoSmsProvider);
      ref.invalidate(clavesIngestaProvider);
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _copiarScriptGmail() async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _trabajando = true);
    try {
      await _revocarLasDe(_nombreGmail);
      final (_, clave) = await ref
          .read(repositorioIngestaProvider)
          .crearClave(_nombreGmail);
      await Clipboard.setData(
        ClipboardData(
          text: scriptGmail(urlApi: Configuracion.urlApi, clave: clave),
        ),
      );
      setState(
        () => _aviso =
            'Script copiado. Pégalo en un proyecto nuevo de script.google.com, '
            'elige «instalar» y pulsa Ejecutar. Lleva una clave nueva: el script '
            'que hubiera antes deja de funcionar.',
      );
    } on ErrorApi catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      ref.invalidate(clavesIngestaProvider);
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sms = ref.watch(estadoSmsProvider).valueOrNull;
    final claves = ref.watch(clavesIngestaProvider).valueOrNull ?? const [];
    final textos = Theme.of(context).textTheme;
    final c = context.colores;
    final ancho = Pantalla.esEscritorio(context) ? 640.0 : double.infinity;
    final gmail = claves.where((k) => k.nombre == _nombreGmail).firstOrNull;

    String usada(DateTime? fecha) => fecha == null
        ? 'Aún no ha enviado nada'
        : 'Último aviso: ${Formato.fechaCorta(fecha)} · ${Formato.hora(fecha)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Registro automático')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espacio.lateral,
              Espacio.s,
              Espacio.lateral,
              40,
            ),
            children: [
              Text(
                'Los movimientos que avisa el banco llegan solos a «Por revisar». '
                'Nada se registra sin que lo veas. Lo que el banco no avisa '
                '(lo que entra desde Nequi) se completa importando el extracto.',
                style: textos.bodyMedium?.copyWith(color: c.tinta2),
              ),
              if (_aviso != null) ...[
                const SizedBox(height: Espacio.l),
                CajaAviso(
                  tono: Tono.positivo,
                  icono: Iconos.listo,
                  texto: TextSpan(text: _aviso),
                ),
              ],
              if (sms != null)
                Seccion(
                  titulo: 'SMS del banco',
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          sms.activo
                              ? 'Activo en este teléfono'
                              : 'Lee los SMS de Bancolombia al llegar, aunque la app '
                                    'esté cerrada. Solo se envían esos; el resto de tus '
                                    'mensajes ni se toca.',
                          style: textos.titleSmall,
                        ),
                        if (sms.activo) ...[
                          const SizedBox(height: Espacio.xs),
                          Text(
                            [
                              if (sms.ultimoEnvio != null)
                                'Último envío: ${Formato.fechaCorta(sms.ultimoEnvio!)} · '
                                    '${Formato.hora(sms.ultimoEnvio!)}',
                              if (sms.pendientes > 0)
                                '${sms.pendientes} esperando conexión',
                            ].join(' · '),
                            style: textos.bodySmall?.copyWith(color: c.tinta2),
                          ),
                        ],
                        const SizedBox(height: Espacio.m),
                        if (sms.activo)
                          OutlinedButton(
                            onPressed: _trabajando ? null : _apagarSms,
                            child: const Text('Dejar de leer los SMS'),
                          )
                        else
                          FilledButton(
                            onPressed: _trabajando ? null : _activarSms,
                            child: Text(
                              _trabajando
                                  ? 'Activando…'
                                  : 'Leer los SMS del banco',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Seccion(
                titulo: 'Correos de Gmail',
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        gmail != null
                            ? 'Conectado · ${usada(gmail.usada)}'
                            : 'Un pequeño script en tu cuenta de Google revisa los '
                                  'correos de «Alertas y Notificaciones» cada 5 minutos '
                                  'y manda solo la frase del aviso.',
                        style: textos.titleSmall,
                      ),
                      const SizedBox(height: Espacio.m),
                      OutlinedButton.icon(
                        onPressed: _trabajando ? null : _copiarScriptGmail,
                        icon: const Icon(Iconos.recibo),
                        label: Text(
                          gmail != null
                              ? 'Copiar el script con una clave nueva'
                              : 'Copiar el script',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (claves.isNotEmpty)
                Seccion(
                  titulo: 'Claves activas',
                  child: Panel.lista(
                    filas: [
                      for (final k in claves)
                        Fila(
                          inicio: IconoCaja(
                            k.nombre == _nombreGmail
                                ? Iconos.recibo
                                : Iconos.billetera,
                          ),
                          titulo: k.nombre,
                          subtitulo: usada(k.usada),
                          final_: TextButton(
                            onPressed: _trabajando
                                ? null
                                : () async {
                                    if (k.nombre == _nombreTelefono) {
                                      await _apagarSms();
                                    } else {
                                      await ref
                                          .read(repositorioIngestaProvider)
                                          .revocar(k.id);
                                      ref.invalidate(clavesIngestaProvider);
                                    }
                                  },
                            child: const Text('Revocar'),
                          ),
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
