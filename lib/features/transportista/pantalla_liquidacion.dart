import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/vista_async.dart';
import 'api_transportista.dart';
import 'modelos_transportista.dart';

/// «Mi liquidación»: entregas hechas con su tarifa y comisión, y lo pendiente por pagar.
class PantallaLiquidacion extends ConsumerWidget {
  const PantallaLiquidacion({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    ref.invalidate(liquidacionProvider);
    try {
      await ref.read(liquidacionProvider.future);
    } catch (_) {
      // El error se ve en pantalla.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liquidacion = ref.watch(liquidacionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi liquidación')),
      body: RefreshIndicator(
        onRefresh: () => _recargar(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            VistaAsync(
              valor: liquidacion,
              alReintentar: () => _recargar(ref),
              datos: (datos) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Totales(resumen: datos),
                  const TituloSeccion('Entregas'),
                  if (datos.items.isEmpty)
                    const ListaVacia(icono: Icons.payments_outlined, texto: 'Aún no tienes entregas liquidadas.')
                  else
                    for (final item in datos.items) _TarjetaLiquidacion(item: item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totales extends StatelessWidget {
  const _Totales({required this.resumen});

  final ResumenLiquidacion resumen;

  Widget _total(String etiqueta, double valor, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              pesos(valor),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            Text(etiqueta, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            _total('Pendiente', resumen.totalPendiente, ColoresNovaTech.naranja),
            _total('Pagado', resumen.totalPagado, ColoresNovaTech.verde),
            _total('Total', resumen.totalComision, ColoresNovaTech.marino),
          ],
        ),
      ),
    );
  }
}

class _TarjetaLiquidacion extends StatelessWidget {
  const _TarjetaLiquidacion({required this.item});

  final Liquidacion item;

  @override
  Widget build(BuildContext context) {
    final fecha = item.fecha;
    final pago = item.fechaPago;
    final porcentaje = item.comisionPorcentaje % 1 == 0
        ? item.comisionPorcentaje.toStringAsFixed(0)
        : item.comisionPorcentaje.toStringAsFixed(1).replaceAll('.', ',');
    return Card(
      child: ListTile(
        title: Text(item.pedido, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (fecha != null) fechaHora(fecha),
          'tarifa ${pesos(item.tarifa)} · $porcentaje %',
          if (item.pagada && pago != null) 'pagada el ${fechaCorta(pago)}',
        ].join('\n')),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(pesos(item.comision), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
              item.pagada ? 'Pagada' : 'Pendiente',
              style: TextStyle(
                color: item.pagada ? ColoresNovaTech.verde : ColoresNovaTech.naranja,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
