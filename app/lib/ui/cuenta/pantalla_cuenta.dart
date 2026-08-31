import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../estado/autenticacion.dart';
import 'widgets/acerca_de.dart';

/// Ajustes de la cuenta.
///
/// La aplicación es de uso personal y el registro está cerrado, así que aquí no se crean
/// cuentas: solo se cambian las credenciales de la única que existe.
class PantallaCuenta extends ConsumerWidget {
  const PantallaCuenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sesionProvider);
    if (estado is! SesionAbierta) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sesion = estado.sesion;
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: esquema.primaryContainer,
                        child: Text(
                          sesion.nombre.isEmpty
                              ? '?'
                              : sesion.nombre[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: esquema.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sesion.nombre,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              sesion.email,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: esquema.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Nombre'),
                      subtitle: Text(sesion.nombre),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _cambiarNombre(context, ref, sesion.nombre),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: const Text('Correo de acceso'),
                      subtitle: Text(sesion.email),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _cambiarEmail(context, ref),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Contraseña'),
                      subtitle: const Text('Cierra el resto de sesiones'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _cambiarPassword(context, ref),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const TarjetaVersion(),

              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Tema.negativo),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Tema.negativo),
                  ),
                  onTap: () => ref.read(sesionProvider.notifier).cerrarSesion(),
                ),
              ),

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'El registro de cuentas nuevas está cerrado: esta aplicación es solo tuya. '
                  'Cambiar el correo o la contraseña cierra la sesión en los demás '
                  'dispositivos.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cambiarNombre(
    BuildContext context,
    WidgetRef ref,
    String actual,
  ) async {
    final campo = TextEditingController(text: actual);

    final nombre = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Cambiar nombre'),
        content: TextField(
          controller: campo,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, campo.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (nombre == null || nombre.isEmpty || !context.mounted) return;

    await _ejecutar(context, () async {
      await ref.read(cuentaProvider).cambiarNombre(nombre);
      // El nombre vive en la sesión guardada, así que hace falta volver a entrar para verlo
      // actualizado en toda la aplicación.
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nombre actualizado')));
      }
    });
  }

  Future<void> _cambiarEmail(BuildContext context, WidgetRef ref) async {
    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _DialogoDosCampos(
        titulo: 'Cambiar correo',
        etiquetaPrimero: 'Correo nuevo',
        etiquetaSegundo: 'Tu contraseña',
        segundoEsPassword: true,
        ayuda: 'Se cerrará la sesión en los demás dispositivos',
      ),
    );

    if (resultado == null || !context.mounted) return;

    await _ejecutar(context, () async {
      await ref
          .read(cuentaProvider)
          .cambiarEmail(emailNuevo: resultado.$1, password: resultado.$2);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo actualizado. Vuelve a entrar.')),
        );
        await ref.read(sesionProvider.notifier).cerrarSesion();
      }
    });
  }

  Future<void> _cambiarPassword(BuildContext context, WidgetRef ref) async {
    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _DialogoDosCampos(
        titulo: 'Cambiar contraseña',
        etiquetaPrimero: 'Contraseña actual',
        etiquetaSegundo: 'Contraseña nueva',
        primeroEsPassword: true,
        segundoEsPassword: true,
        ayuda: 'Mínimo 8 caracteres. Se cerrarán las demás sesiones',
      ),
    );

    if (resultado == null || !context.mounted) return;

    await _ejecutar(context, () async {
      await ref
          .read(cuentaProvider)
          .cambiarPassword(actual: resultado.$1, nueva: resultado.$2);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada. Vuelve a entrar.'),
          ),
        );
        await ref.read(sesionProvider.notifier).cerrarSesion();
      }
    });
  }

  Future<void> _ejecutar(
    BuildContext context,
    Future<void> Function() accion,
  ) async {
    try {
      await accion();
    } on ErrorApi catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    }
  }
}

/// Diálogo con dos campos, para los cambios que exigen confirmar con la contraseña.
class _DialogoDosCampos extends StatefulWidget {
  const _DialogoDosCampos({
    required this.titulo,
    required this.etiquetaPrimero,
    required this.etiquetaSegundo,
    required this.ayuda,
    this.primeroEsPassword = false,
    this.segundoEsPassword = false,
  });

  final String titulo;
  final String etiquetaPrimero;
  final String etiquetaSegundo;
  final String ayuda;
  final bool primeroEsPassword;
  final bool segundoEsPassword;

  @override
  State<_DialogoDosCampos> createState() => _DialogoDosCamposState();
}

class _DialogoDosCamposState extends State<_DialogoDosCampos> {
  final _primero = TextEditingController();
  final _segundo = TextEditingController();

  @override
  void dispose() {
    _primero.dispose();
    _segundo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _primero,
            autofocus: true,
            obscureText: widget.primeroEsPassword,
            keyboardType: widget.primeroEsPassword
                ? TextInputType.text
                : TextInputType.emailAddress,
            decoration: InputDecoration(labelText: widget.etiquetaPrimero),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _segundo,
            obscureText: widget.segundoEsPassword,
            decoration: InputDecoration(
              labelText: widget.etiquetaSegundo,
              helperText: widget.ayuda,
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_primero.text.trim().isEmpty || _segundo.text.isEmpty) return;
            Navigator.pop(context, (_primero.text.trim(), _segundo.text));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
