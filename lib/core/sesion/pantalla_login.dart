import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/cliente_api.dart';
import '../tema/tema.dart';
import '../widgets/marca.dart';
import 'sesion.dart';

/// Login del personal. Lo único que se escribe en toda la app: usuario y contraseña.
/// Después del primer ingreso se puede activar la huella o el reconocimiento facial.
class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _ocultar = true;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<bool> _preguntarHuella() async {
    final activar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Entrar con tu huella?'),
        content: const Text(
          'Puedes entrar la próxima vez con tu huella o rostro, sin escribir nada. '
          'Tu acceso se guarda de forma segura en este celular.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    return activar ?? false;
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await accion();
      // Si salió bien, el enrutador cambia de pantalla solo.
    } on ErrorApi catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ingresar() async {
    final usuario = _usuario.text.trim();
    final password = _password.text;
    if (usuario.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu usuario y tu contraseña.');
      return;
    }
    await _ejecutar(
      () => ref
          .read(sesionProvider.notifier)
          .iniciarSesion(usuario, password, ofrecerHuella: _preguntarHuella),
    );
  }

  Future<void> _entrarConHuella() =>
      _ejecutar(() => ref.read(sesionProvider.notifier).entrarConHuella());

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);
    final puedeHuella = sesion.huellaActiva && sesion.huellaDisponible;
    final mensaje = _error ?? sesion.aviso;

    return Scaffold(
      backgroundColor: ColoresNovaTech.marino,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoNovaTech(),
                  const SizedBox(height: 8),
                  const Text(
                    'App del personal',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Iniciar sesión',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _usuario,
                            enabled: !_cargando,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            enabled: !_cargando,
                            obscureText: _ocultar,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _ingresar(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _ocultar = !_ocultar),
                              ),
                            ),
                          ),
                          if (mensaje != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ColoresNovaTech.rojo.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ColoresNovaTech.rojo.withOpacity(0.4)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline, color: ColoresNovaTech.rojo, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(mensaje)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _cargando ? null : _ingresar,
                            child: _cargando
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Text('Ingresar'),
                          ),
                          if (puedeHuella) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _cargando ? null : _entrarConHuella,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Entrar con huella'),
                            ),
                            TextButton(
                              onPressed: _cargando
                                  ? null
                                  : () => ref.read(sesionProvider.notifier).olvidarHuella(),
                              child: const Text('Usar otra cuenta (olvidar huella)'),
                            ),
                          ],
                        ],
                      ),
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
