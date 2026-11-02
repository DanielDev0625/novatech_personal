import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/sesion/sesion.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_admin.dart';

/// «Usuarios y roles»: cuentas del personal, activar o desactivar y crear nuevas.
class PantallaUsuarios extends ConsumerStatefulWidget {
  const PantallaUsuarios({super.key});

  @override
  ConsumerState<PantallaUsuarios> createState() => _PantallaUsuariosState();
}

class _PantallaUsuariosState extends ConsumerState<PantallaUsuarios> {
  /// Cuentas con un cambio de estado en curso.
  final Set<int> _cambiando = {};

  Future<void> _recargar() async {
    ref.invalidate(usuariosProvider);
    try {
      await ref.read(usuariosProvider.future);
    } catch (_) {
      // El error se ve en la lista.
    }
  }

  Future<void> _cambiarEstado(Usuario usuario, bool activo) async {
    if (!activo) {
      final ok = await confirmar(
        context,
        titulo: 'Desactivar cuenta',
        texto: '${usuario.nombre} no podrá iniciar sesión hasta que la vuelvas a activar.',
        aceptar: 'Desactivar',
      );
      if (!ok) return;
    }
    setState(() => _cambiando.add(usuario.id));
    try {
      await ref.read(apiAdminProvider).cambiarEstadoUsuario(usuario.id, activo: activo);
      await _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cambiando.remove(usuario.id));
    }
  }

  Future<void> _crear() async {
    final creada = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CrearCuenta(),
    );
    if (creada != null && mounted) {
      mostrarMensaje(context, 'Cuenta de $creada creada.');
      await _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = ref.watch(usuariosProvider);
    final yo = ref.watch(sesionProvider).usuario?.id;

    return EsqueletoRol(
      titulo: 'Usuarios y roles',
      alRecargar: _recargar,
      accionInferior: FilledButton.icon(
        onPressed: _crear,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Crear cuenta del personal'),
      ),
      hijos: [
        VistaAsync(
          valor: usuarios,
          alReintentar: _recargar,
          datos: (lista) => lista.isEmpty
              ? const ListaVacia(icono: Icons.group_outlined, texto: 'Aún no hay cuentas del personal.')
              : Column(
                  children: [
                    for (final u in lista)
                      Card(
                        child: ListTile(
                          leading: AvatarPersona(nombre: u.nombre, rol: u.rol),
                          title: Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                EtiquetaRol(rol: u.rol),
                                Text(
                                  '@${u.usuario}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          trailing: _cambiando.contains(u.id)
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : Switch(
                                  value: u.activo,
                                  activeTrackColor: ColoresNovaTech.verde,
                                  // No se puede desactivar la propia cuenta.
                                  onChanged: u.id == yo ? null : (v) => _cambiarEstado(u, v),
                                ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Crear una cuenta: nombre, usuario y contraseña se escriben; el rol se elige.
class _CrearCuenta extends ConsumerStatefulWidget {
  const _CrearCuenta();

  @override
  ConsumerState<_CrearCuenta> createState() => _CrearCuentaState();
}

class _CrearCuentaState extends ConsumerState<_CrearCuenta> {
  final _nombre = TextEditingController();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  Rol _rol = Rol.operario;
  bool _enviando = false;
  bool _ocultar = true;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    final usuario = _usuario.text.trim();
    final password = _password.text;
    if (nombre.isEmpty || usuario.isEmpty || password.isEmpty) {
      setState(() => _error = 'Completa nombre, usuario y contraseña.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(apiAdminProvider).crearUsuario(nombre: nombre, usuario: usuario, password: password, rol: _rol);
      if (mounted) Navigator.pop(context, nombre);
    } catch (e) {
      if (mounted) setState(() => _error = errorDesde(e).mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Crear cuenta del personal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _nombre,
                enabled: !_enviando,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Nombre completo', prefixIcon: Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _usuario,
                enabled: !_enviando,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Usuario', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                enabled: !_enviando,
                obscureText: _ocultar,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'Contraseña inicial',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Rol', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final rol in Rol.values.where((r) => r.esPersonal))
                    ChoiceChip(
                      label: Text(rol.etiqueta),
                      selected: _rol == rol,
                      onSelected: _enviando ? null : (_) => setState(() => _rol = rol),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: ColoresNovaTech.rojo)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _enviando ? null : _guardar,
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
