import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';
import 'modelos_operario.dart';

/// Compras aprobadas que esperan llegar a la bodega.
class PantallaRecepcion extends ConsumerWidget {
  const PantallaRecepcion({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    ref.invalidate(comprasPorRecibirProvider);
    try {
      await ref.read(comprasPorRecibirProvider.future);
    } catch (_) {
      // El error se ve en la lista.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compras = ref.watch(comprasPorRecibirProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recepción de mercancía')),
      body: RefreshIndicator(
        onRefresh: () => _recargar(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            VistaAsync(
              valor: compras,
              alReintentar: () => _recargar(ref),
              datos: (lista) => lista.isEmpty
                  ? const ListaVacia(
                      icono: Icons.inventory_2_outlined,
                      texto: 'No hay compras aprobadas por recibir.',
                    )
                  : Column(
                      children: [
                        for (final compra in lista)
                          _TarjetaCompra(
                            compra: compra,
                            onTap: () async {
                              await context.push('/operario/recibir/${compra.id}');
                              if (context.mounted) ref.invalidate(comprasPorRecibirProvider);
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCompra extends StatelessWidget {
  const _TarjetaCompra({required this.compra, required this.onTap});

  final Compra compra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final estimada = compra.fechaEstimada;
    final detalles = [
      compra.codigo,
      if (compra.proveedor != null) compra.proveedor!,
      if (estimada != null) 'llega ${diaRelativo(estimada)}',
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(compra.producto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(compra.sku, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(detalles.join(' · '), style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    if (compra.atrasada)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Atrasada ${compra.diasAtraso} ${compra.diasAtraso == 1 ? 'día' : 'días'}',
                          style: const TextStyle(color: ColoresNovaTech.rojo, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${compra.cantidad}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ColoresNovaTech.marino),
                  ),
                  const Text('unidades', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
