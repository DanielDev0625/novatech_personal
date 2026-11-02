import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/acceso.dart';
import '../../core/widgets/aviso_salida.dart';
import '../../core/widgets/scaffold_rol.dart';
import 'api_operario.dart';

/// Inicio del operario: accesos con conteos y el aviso de fin de jornada.
class PantallaOperario extends ConsumerWidget {
  const PantallaOperario({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    recargarOperario(ref);
    try {
      await Future.wait([
        ref.read(colaProvider.future),
        ref.read(alistandoProvider.future),
        ref.read(comprasPorRecibirProvider.future),
      ]);
    } catch (_) {
      // Cada acceso muestra «–» si su conteo no cargó; no hace falta otro aviso.
    }
  }

  Future<void> _ir(BuildContext context, WidgetRef ref, String ruta) async {
    await context.push(ruta);
    // Al volver, los conteos pueden haber cambiado.
    if (context.mounted) recargarOperario(ref);
  }

  String? _conteo<T>(AsyncValue<List<T>> valor) => valor.whenOrNull(data: (lista) => '${lista.length}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cola = ref.watch(colaProvider);
    final alistando = ref.watch(alistandoProvider);
    final compras = ref.watch(comprasPorRecibirProvider);
    final enCurso = alistando.valueOrNull?.length ?? 0;

    return ScaffoldRol(
      titulo: 'Operario',
      alRecargar: () => _recargar(ref),
      contenido: [
        const AvisoSalida(),
        const SizedBox(height: 8),
        Acceso(
          icono: Icons.checklist,
          titulo: 'Mis tareas',
          descripcion: enCurso > 0
              ? 'Tienes $enCurso ${enCurso == 1 ? 'pedido' : 'pedidos'} en alistamiento.'
              : 'Pedidos por alistar, los más antiguos primero.',
          conteo: _conteo(cola),
          etiquetaConteo: 'en cola',
          onTap: () => _ir(context, ref, '/operario/tareas'),
        ),
        Acceso(
          icono: Icons.inventory_2_outlined,
          titulo: 'Recepción de mercancía',
          descripcion: 'Cuenta lo que llegó de cada compra aprobada.',
          conteo: _conteo(compras),
          etiquetaConteo: 'por recibir',
          onTap: () => _ir(context, ref, '/operario/recepcion'),
        ),
        Acceso(
          icono: Icons.schedule,
          titulo: 'Mi jornada',
          descripcion: 'Tu horario de hoy y tus horas extra.',
          onTap: () => _ir(context, ref, '/operario/jornada'),
        ),
      ],
    );
  }
}
