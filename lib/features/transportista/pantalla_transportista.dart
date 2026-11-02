import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/acceso.dart';
import '../../core/widgets/aviso_salida.dart';
import '../../core/widgets/scaffold_rol.dart';
import 'api_transportista.dart';

/// Inicio del transportista: recibir paquetes, la ruta y la liquidación.
class PantallaTransportista extends ConsumerWidget {
  const PantallaTransportista({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    recargarTransportista(ref);
    try {
      await Future.wait([
        ref.read(zonaEnviosProvider.future),
        ref.read(rutaProvider.future),
        ref.read(liquidacionProvider.future),
      ]);
    } catch (_) {
      // Cada acceso muestra «–» si su dato no cargó.
    }
  }

  Future<void> _ir(BuildContext context, WidgetRef ref, String ruta) async {
    await context.push(ruta);
    if (context.mounted) recargarTransportista(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Con entregas en ruta, la app comparte la ubicación para el seguimiento del cliente.
    ref.listen(rutaProvider, (_, ruta) {
      ruta.whenData((r) => ref.read(compartirUbicacionProvider.notifier).activar(r.hayEnRuta));
    });

    final zona = ref.watch(zonaEnviosProvider);
    final ruta = ref.watch(rutaProvider);
    final liquidacion = ref.watch(liquidacionProvider);
    final compartiendo = ref.watch(compartirUbicacionProvider);
    final paradas = ruta.valueOrNull?.paradas;
    final porSalir = paradas?.where((p) => p.porSalir).length ?? 0;

    return ScaffoldRol(
      titulo: 'Transportista',
      alRecargar: () => _recargar(ref),
      contenido: [
        const AvisoSalida(),
        if (compartiendo)
          const Card(
            color: ColoresNovaTech.verde,
            child: ListTile(
              leading: Icon(Icons.my_location, color: Colors.white),
              title: Text(
                'Compartiendo tu ubicación',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Tus clientes ven por dónde va su pedido mientras estás en ruta.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Acceso(
          icono: Icons.qr_code_scanner,
          titulo: 'Recibir paquetes',
          descripcion: 'Escanea el QR de cada paquete en la zona de envíos.',
          conteo: zona.whenOrNull(data: (l) => '${l.length}'),
          etiquetaConteo: 'listos',
          onTap: () => _ir(context, ref, '/transportista/recibir'),
        ),
        Acceso(
          icono: Icons.map_outlined,
          titulo: 'Mi ruta',
          descripcion: porSalir > 0
              ? 'Tienes $porSalir ${porSalir == 1 ? 'paquete' : 'paquetes'} por salir: inicia la ruta.'
              : 'Paradas en orden, mapa y confirmación de entrega.',
          conteo: paradas == null ? null : '${paradas.length}',
          etiquetaConteo: 'paradas',
          onTap: () => _ir(context, ref, '/transportista/ruta'),
        ),
        Acceso(
          icono: Icons.payments_outlined,
          titulo: 'Mi liquidación',
          descripcion: liquidacion.whenOrNull(
                data: (l) => 'Pendiente por pagar: ${pesos(l.totalPendiente)}',
              ) ??
              'Tus entregas, tarifas y comisiones.',
          onTap: () => _ir(context, ref, '/transportista/liquidacion'),
        ),
      ],
    );
  }
}
