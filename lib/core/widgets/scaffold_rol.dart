import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/modelos.dart';
import '../formato.dart';
import '../sesion/sesion.dart';
import '../tema/tema.dart';
import 'componentes.dart';
import 'marca.dart';
import 'vista_async.dart';

/// Barra superior de NovaTech: azul marino con las franjas de la marca debajo.
/// Con [etiqueta] muestra dos líneas (p. ej. «Operario» / «Mis tareas»), como en el diseño.
PreferredSizeWidget barraNovaTech({
  required String titulo,
  String? etiqueta,
  Widget? chip,
  List<Widget>? acciones,
}) {
  final alto = (etiqueta != null ? 64.0 : kToolbarHeight) + (chip != null ? 36 : 0);
  return AppBar(
    toolbarHeight: alto,
    titleSpacing: etiqueta != null ? 20 : null,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (etiqueta != null)
          Text(etiqueta, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w400)),
        Text(
          titulo,
          style: TextStyle(fontSize: etiqueta != null ? 22 : 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        if (chip != null) ...[const SizedBox(height: 8), chip],
      ],
    ),
    actions: acciones,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(4),
      child: FranjaColores(ancho: double.infinity, alto: 4),
    ),
  );
}

/// Chip claro sobre el encabezado marino (p. ej. «Jornada 7:00 a 19:00»).
class ChipEncabezado extends StatelessWidget {
  const ChipEncabezado({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla principal de una pestaña del rol: encabezado con el nombre del rol,
/// botón de la cuenta, lista con jalar-para-recargar y un botón grande abajo.
class EsqueletoRol extends ConsumerWidget {
  const EsqueletoRol({
    super.key,
    required this.titulo,
    required this.hijos,
    this.chip,
    this.alRecargar,
    this.accionInferior,
  });

  final String titulo;
  final Widget? chip;
  final List<Widget> hijos;
  final Future<void> Function()? alRecargar;

  /// Botón grande fijo abajo (p. ej. «Iniciar ruta»).
  final Widget? accionInferior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).usuario;
    if (usuario == null) return const SizedBox.shrink();

    final lista = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: hijos,
    );
    final recargar = alRecargar;

    return Scaffold(
      appBar: barraNovaTech(
        etiqueta: usuario.rol.etiqueta,
        titulo: titulo,
        chip: chip,
        acciones: const [BotonCuenta()],
      ),
      body: Column(
        children: [
          Expanded(child: recargar == null ? lista : RefreshIndicator(onRefresh: recargar, child: lista)),
          if (accionInferior != null)
            SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: accionInferior),
            ),
        ],
      ),
    );
  }
}

/// Botón con las iniciales de la persona; abre el menú de la cuenta.
class BotonCuenta extends ConsumerWidget {
  const BotonCuenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).usuario;
    if (usuario == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        tooltip: 'Tu cuenta',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => const _MenuCuenta(),
        ),
        icon: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          child: Text(
            iniciales(usuario.nombre),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _MenuCuenta extends ConsumerWidget {
  const _MenuCuenta();

  Future<void> _salir(BuildContext context, WidgetRef ref, Usuario usuario) async {
    final ok = await confirmar(
      context,
      titulo: 'Cerrar sesión',
      texto: usuario.rol.tieneJornada
          ? 'Al salir se cierra tu jornada de hoy. ¿Quieres continuar?'
          : '¿Quieres cerrar tu sesión?',
      aceptar: 'Salir',
    );
    if (!ok) return;
    if (context.mounted) Navigator.pop(context);
    await ref.read(sesionProvider.notifier).cerrarSesion();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    final usuario = sesion.usuario;
    if (usuario == null) return const SizedBox.shrink();
    final expira = sesion.expira;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AvatarPersona(nombre: usuario.nombre, rol: usuario.rol, radio: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('@${usuario.usuario}', style: const TextStyle(color: ColoresNovaTech.textoSuave)),
                    ],
                  ),
                ),
                EtiquetaRol(rol: usuario.rol),
              ],
            ),
            if (usuario.rol.tieneJornada && expira != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: ColoresNovaTech.naranja),
                  const SizedBox(width: 8),
                  Text('Tu sesión dura hasta las ${hora(expira)}.'),
                ],
              ),
            ],
            if (sesion.huellaActiva) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fingerprint),
                title: const Text('Ingreso con huella activo'),
                trailing: TextButton(
                  onPressed: () => ref.read(sesionProvider.notifier).olvidarHuella(),
                  child: const Text('Desactivar'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresNovaTech.rojo,
                side: const BorderSide(color: ColoresNovaTech.rojo),
              ),
              onPressed: () => _salir(context, ref, usuario),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
            const SizedBox(height: 16),
            const Center(child: SimboloNovaTech(tamano: 28)),
          ],
        ),
      ),
    );
  }
}

/// «Laura Pérez» → «LP».
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  final primera = partes.first[0];
  final segunda = partes.length > 1 ? partes[1][0] : '';
  return (primera + segunda).toUpperCase();
}

/// Color que identifica a cada rol (los acentos de la marca).
Color colorRol(Rol rol) => switch (rol) {
      Rol.operario => ColoresNovaTech.verde,
      Rol.transportista => ColoresNovaTech.naranja,
      Rol.gerente => ColoresNovaTech.azul,
      Rol.administrador => ColoresNovaTech.rojo,
      Rol.usuario => ColoresNovaTech.textoSuave,
    };

class AvatarPersona extends StatelessWidget {
  const AvatarPersona({super.key, required this.nombre, required this.rol, this.radio = 20});

  final String nombre;
  final Rol rol;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final color = colorRol(rol);
    return CircleAvatar(
      radius: radio,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Text(
        iniciales(nombre),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: radio * 0.7),
      ),
    );
  }
}

class EtiquetaRol extends StatelessWidget {
  const EtiquetaRol({super.key, required this.rol});

  final Rol rol;

  @override
  Widget build(BuildContext context) => Insignia(texto: rol.etiqueta, color: colorRol(rol));
}

/// Una pestaña de la navegación inferior.
class Pestana {
  const Pestana(this.icono, this.iconoActivo, this.etiqueta);

  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
}

/// Navegación inferior del rol: cada pestaña conserva su pantalla al cambiar.
class ShellRol extends StatelessWidget {
  const ShellRol({super.key, required this.shell, required this.pestanas});

  final StatefulNavigationShell shell;
  final List<Pestana> pestanas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: ColoresNovaTech.borde))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          // Tocar la pestaña activa vuelve a su pantalla inicial.
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            for (final p in pestanas)
              NavigationDestination(icon: Icon(p.icono), selectedIcon: Icon(p.iconoActivo), label: p.etiqueta),
          ],
        ),
      ),
    );
  }
}
