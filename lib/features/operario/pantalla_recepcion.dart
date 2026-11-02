import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';

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
    return EsqueletoRol(
      titulo: 'Recepción de mercancía',
      alRecargar: () => _recargar(ref),
      hijos: [
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
      shape: compra.atrasada
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: ColoresNovaTech.naranja),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(compra.producto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      'Aprobado ${compra.cantidad} · SKU ${compra.sku}',
                      style: const TextStyle(color: ColoresNovaTech.textoSuave),
                    ),
                    Text(detalles.join(' · '), style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
                    if (compra.atrasada) ...[
                      const SizedBox(height: 6),
                      Insignia(
                        texto: 'Atrasada ${compra.diasAtraso} ${compra.diasAtraso == 1 ? 'día' : 'días'}',
                        color: ColoresNovaTech.naranja,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ColoresNovaTech.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}
