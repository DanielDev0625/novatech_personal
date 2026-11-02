import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/modelos.dart';
import '../formato.dart';
import '../sesion/sesion.dart';
import '../tema/tema.dart';
import 'marca.dart';

/// Una función que llegará en una fase siguiente.
class ModuloPendiente {
  const ModuloPendiente(this.icono, this.titulo, this.descripcion);

  final IconData icono;
  final String titulo;
  final String descripcion;
}

/// Estructura común de la pantalla de inicio de cada rol: barra con el nombre,
/// botón de salir, el [contenido] del rol y la lista de lo que traerán las fases siguientes.
class ScaffoldRol extends ConsumerWidget {
  const ScaffoldRol({
    super.key,
    required this.titulo,
    this.fase = '',
    this.modulos = const [],
    this.contenido = const [],
    this.alRecargar,
  });

  final String titulo;
  final String fase;
  final List<ModuloPendiente> modulos;

  /// Lo que ya funciona en este rol (va debajo del saludo).
  final List<Widget> contenido;

  /// Si se da, la lista se puede jalar hacia abajo para recargar.
  final Future<void> Function()? alRecargar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    final usuario = sesion.usuario;
    if (usuario == null) return const SizedBox.shrink();
    final expira = sesion.expira;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(usuario.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _salir(context, ref, usuario),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: FranjaColores(ancho: double.infinity, alto: 4),
        ),
      ),
      body: _conRecarga(ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${usuario.nombre}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Entraste como ${usuario.rol.etiqueta.toLowerCase()}.'),
                  if (usuario.rol.tieneJornada && expira != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 18, color: ColoresNovaTech.naranja),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Tu sesión dura hasta las ${hora(expira)}.')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          ...contenido,
          if (modulos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Próximamente · $fase',
              style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresNovaTech.texto),
            ),
            const SizedBox(height: 8),
            for (final modulo in modulos)
              Card(
                child: ListTile(
                  leading: Icon(modulo.icono, color: ColoresNovaTech.azul),
                  title: Text(modulo.titulo),
                  subtitle: Text(modulo.descripcion),
                  trailing: const Icon(Icons.lock_outline, size: 18),
                ),
              ),
          ],
        ],
      )),
    );
  }

  Widget _conRecarga(Widget lista) {
    final recargar = alRecargar;
    return recargar == null ? lista : RefreshIndicator(onRefresh: recargar, child: lista);
  }

  Future<void> _salir(BuildContext context, WidgetRef ref, Usuario usuario) async {
    final cierraJornada = usuario.rol.tieneJornada;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Text(
          cierraJornada
              ? 'Al salir se cierra tu jornada de hoy. ¿Quieres continuar?'
              : '¿Quieres cerrar tu sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await ref.read(sesionProvider.notifier).cerrarSesion();
    }
  }
}
