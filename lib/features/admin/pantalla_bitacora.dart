import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/adaptable.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_admin.dart';
import 'modelos_admin.dart';

/// «Bitácora»: aprobaciones, horarios configurados e intentos de ingreso fuera de horario.
class PantallaBitacora extends ConsumerWidget {
  const PantallaBitacora({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    ref.invalidate(bitacoraProvider);
    try {
      await ref.read(bitacoraProvider.future);
    } catch (_) {
      // El error se ve en la lista.
    }
  }

  static (IconData, Color) _icono(String accion) {
    final a = accion.toLowerCase();
    if (a.contains('fuera') || a.contains('rechaz') || a.contains('fall')) {
      return (Icons.block, ColoresNovaTech.rojo);
    }
    if (a.contains('aprob')) return (Icons.check_circle_outline, ColoresNovaTech.verde);
    if (a.contains('horario') || a.contains('hora')) return (Icons.schedule, ColoresNovaTech.azul);
    return (Icons.history, ColoresNovaTech.textoSuave);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bitacora = ref.watch(bitacoraProvider);
    return Scaffold(
      appBar: barraNovaTech(titulo: 'Bitácora'),
      body: ContenidoCentrado(
        child: RefreshIndicator(
          onRefresh: () => _recargar(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              VistaAsync(
                valor: bitacora,
                alReintentar: () => _recargar(ref),
                datos: (lista) => lista.isEmpty
                    ? const ListaVacia(icono: Icons.history, texto: 'La bitácora está vacía.')
                    : Column(children: [for (final e in lista) _Entrada(entrada: e)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Entrada extends StatelessWidget {
  const _Entrada({required this.entrada});

  final EntradaBitacora entrada;

  @override
  Widget build(BuildContext context) {
    final (icono, color) = PantallaBitacora._icono(entrada.accion);
    final fecha = entrada.fecha;
    final accion = entrada.accion.replaceAll('_', ' ');
    return Card(
      child: ListTile(
        leading: Icon(icono, color: color),
        title: Text(
          accion.isEmpty ? '' : '${accion[0].toUpperCase()}${accion.substring(1)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (entrada.detalle?.isNotEmpty ?? false) entrada.detalle!,
            [if (entrada.usuario != null) entrada.usuario!, if (fecha != null) fechaHora(fecha)].join(' · '),
          ].join('\n'),
        ),
      ),
    );
  }
}
