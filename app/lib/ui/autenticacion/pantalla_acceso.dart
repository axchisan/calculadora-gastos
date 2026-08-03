import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema.dart';
import '../../datos/cliente_api.dart';
import '../../estado/autenticacion.dart';

/// Pantalla única de acceso: alterna entre iniciar sesión y crear cuenta.
///
/// Se unifican porque son el mismo formulario con un campo de diferencia, y separarlas
/// obligaría a navegar de una a otra por un error tan común como equivocarse de modo.
class PantallaAcceso extends ConsumerStatefulWidget {
  const PantallaAcceso({super.key});

  @override
  ConsumerState<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends ConsumerState<PantallaAcceso> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nombre = TextEditingController();

  bool _esRegistro = false;
  bool _enviando = false;
  bool _passwordVisible = false;
  String? _errorGeneral;
  Map<String, String> _erroresPorCampo = const {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _errorGeneral = null;
      _erroresPorCampo = const {};
    });

    if (!_formulario.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      final controlador = ref.read(sesionProvider.notifier);
      if (_esRegistro) {
        await controlador.registrar(
          email: _email.text,
          password: _password.text,
          nombre: _nombre.text,
        );
      } else {
        await controlador.iniciarSesion(
          email: _email.text,
          password: _password.text,
        );
      }
      // La navegación la resuelve el enrutador al cambiar el estado de sesión.
    } on ErrorApi catch (e) {
      if (!mounted) return;
      setState(() {
        _errorGeneral = e.campos.isEmpty ? e.mensaje : null;
        _erroresPorCampo = e.campos;
      });
      // Los errores por campo se muestran en el propio campo, así que hay que revalidar.
      if (e.campos.isNotEmpty) {
        _formulario.currentState!.validate();
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _alternarModo() {
    setState(() {
      _esRegistro = !_esRegistro;
      _errorGeneral = null;
      _erroresPorCampo = const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formulario,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.savings_outlined,
                    size: 56,
                    color: esquema.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Calculadora de gastos',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _esRegistro
                        ? 'Crea tu cuenta para empezar a organizar tu mes'
                        : 'Entra para ver cómo va tu mes',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_esRegistro) ...[
                    TextFormField(
                      controller: _nombre,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: _erroresPorCampo['nombre'],
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: const Icon(Icons.alternate_email),
                      errorText: _erroresPorCampo['email'],
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Escribe tu correo';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'El correo no parece válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _password,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _enviando ? null : _enviar(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _erroresPorCampo['password'],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        tooltip: _passwordVisible ? 'Ocultar' : 'Mostrar',
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Escribe tu contraseña';
                      }
                      // Solo se exige la longitud mínima al registrarse: al entrar, una clave
                      // corta simplemente no coincidirá, y adelantarlo confundiría.
                      if (_esRegistro && v.length < 8) {
                        return 'Debe tener al menos 8 caracteres';
                      }
                      return null;
                    },
                  ),

                  if (_errorGeneral != null) ...[
                    const SizedBox(height: 16),
                    _Aviso(mensaje: _errorGeneral!),
                  ],

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_esRegistro ? 'Crear cuenta' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _enviando ? null : _alternarModo,
                    child: Text(
                      _esRegistro
                          ? '¿Ya tienes cuenta? Entra'
                          : '¿No tienes cuenta? Créala',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Tema.negativo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tema.negativo.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Tema.negativo, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: Tema.negativo, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
