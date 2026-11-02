import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_gerencia.dart';

/// «$4,1 M», «$850 mil» o «$ 12.500»: cifras grandes resumidas para las tarjetas.
String pesosCorto(double valor) {
  if (valor.abs() >= 1000000) return '\$${(valor / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (valor.abs() >= 100000) return '\$${(valor / 1000).round()} mil';
  return pesos(valor);
}

/// «4.860»: número entero con punto de miles.
String entero(double valor) => pesos(valor).replaceFirst('\$ ', '');

/// «Eficiencia energética»: consumo del mes, costo, CO₂, por zona y alertas.
class PantallaEnergia extends ConsumerWidget {
  const PantallaEnergia({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    ref.invalidate(consumoProvider);
    ref.invalidate(alertasEnergiaProvider);
    try {
      await ref.read(consumoProvider.future);
    } catch (_) {
      // El error se ve en pantalla.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumo = ref.watch(consumoProvider);
    final alertas = ref.watch(alertasEnergiaProvider).valueOrNull ?? const [];

    return EsqueletoRol(
      titulo: 'Eficiencia energética',
      alRecargar: () => _recargar(ref),
      hijos: [
        VistaAsync(
          valor: consumo,
          alReintentar: () => _recargar(ref),
          datos: (c) {
            final mayor = c.zonas.isEmpty ? 0.0 : c.zonas.first.kwh;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RejillaIndicadores(
                  indicadores: [
                    Indicador(etiqueta: 'Consumo mes', valor: '${entero(c.totalKwh)} kWh'),
                    Indicador(etiqueta: 'Costo', valor: pesosCorto(c.totalCosto)),
                    Indicador(etiqueta: 'CO₂', valor: '${entero(c.totalCo2Kg)} kg', color: ColoresNovaTech.verde),
                    Indicador(
                      etiqueta: 'kWh por pedido',
                      valor: c.kwhPorPedido == null ? '—' : c.kwhPorPedido!.toStringAsFixed(1).replaceAll('.', ','),
                      detalle: '${c.pedidosDespachados} despachados',
                    ),
                  ],
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Por zona', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (c.zonas.isEmpty)
                          const Text(
                            'Aún no hay zonas con equipos registrados.',
                            style: TextStyle(color: ColoresNovaTech.textoSuave),
                          )
                        else
                          for (final z in c.zonas)
                            FilaBarra(
                              etiqueta: z.zona,
                              proporcion: mayor == 0 ? 0 : z.kwh / mayor,
                              valor: '${entero(z.kwh)} kWh',
                              color: ColoresNovaTech.verde,
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        for (final a in alertas)
          TarjetaAviso(
            icono: Icons.warning_amber_rounded,
            color: ColoresNovaTech.naranja,
            texto: a.mensaje.isEmpty ? a.zona : a.mensaje,
          ),
      ],
    );
  }
}
