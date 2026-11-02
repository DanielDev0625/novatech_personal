import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_gerencia.dart';

/// «Panel del día»: indicadores de hoy y lo que necesita atención.
class PantallaPanel extends ConsumerWidget {
  const PantallaPanel({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    recargarGerencia(ref);
    try {
      await ref.read(panelProvider.future);
    } catch (_) {
      // El error se ve en pantalla.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(panelProvider);
    final sugeridas = ref.watch(comprasSugeridasProvider).valueOrNull;
    final diferencias = ref.watch(comprasConDiferenciasProvider).valueOrNull;
    final solicitudes = ref.watch(horasExtraSolicitadasProvider).valueOrNull;
    final atrasadas = ref.watch(comprasAtrasadasProvider).valueOrNull ?? const [];
    final transportistas = ref.watch(transportistasProvider).valueOrNull ?? const [];

    final porAprobar = sugeridas == null || solicitudes == null || diferencias == null
        ? null
        : sugeridas.length + solicitudes.length + diferencias.length;
    final enRuta = transportistas.where((t) => t.enRuta).length;

    return EsqueletoRol(
      titulo: 'Panel del día',
      alRecargar: () => _recargar(ref),
      hijos: [
        VistaAsync(
          valor: panel,
          alReintentar: () => _recargar(ref),
          datos: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RejillaIndicadores(
                indicadores: [
                  Indicador(etiqueta: 'Pedidos hoy', valor: '${p.pedidos}', detalle: pesos(p.ventasTotal)),
                  Indicador(
                    etiqueta: 'A tiempo',
                    valor: p.porcentajeATiempo == null ? '—' : '${p.porcentajeATiempo!.round()}%',
                    color: ColoresNovaTech.verde,
                    detalle: p.pedidosVencidos > 0 ? '${p.pedidosVencidos} vencidos en curso' : null,
                  ),
                  Indicador(
                    etiqueta: 'Stock bajo',
                    valor: '${p.productosStockBajo}',
                    color: ColoresNovaTech.naranja,
                    onTap: () => context.go('/gerencia/estadisticas'),
                  ),
                  Indicador(
                    etiqueta: 'Por aprobar',
                    valor: porAprobar == null ? '–' : '$porAprobar',
                    color: ColoresNovaTech.azul,
                    onTap: () => context.go('/gerencia/aprobar'),
                  ),
                ],
              ),
              if (atrasadas.isNotEmpty)
                TarjetaAviso(
                  icono: Icons.warning_amber_rounded,
                  color: ColoresNovaTech.rojo,
                  texto: 'Mercancía atrasada: ${atrasadas.map((c) => c.codigo).join(', ')}',
                ),
              if (diferencias != null && diferencias.isNotEmpty)
                TarjetaAviso(
                  icono: Icons.report_problem_outlined,
                  color: ColoresNovaTech.rojo,
                  texto: diferencias.length == 1
                      ? '1 recepción con diferencias por decidir'
                      : '${diferencias.length} recepciones con diferencias por decidir',
                  onTap: () => context.go('/gerencia/aprobar'),
                ),
              if (p.jornadasSinSalida > 0)
                TarjetaAviso(
                  icono: Icons.schedule,
                  color: ColoresNovaTech.naranja,
                  texto: p.jornadasSinSalida == 1
                      ? '1 jornada con salida no registrada'
                      : '${p.jornadasSinSalida} jornadas con salida no registrada',
                ),
              TarjetaAviso(
                icono: Icons.local_shipping_outlined,
                color: ColoresNovaTech.textoSuave,
                texto: enRuta == 1 ? '1 transportista en ruta' : '$enRuta transportistas en ruta',
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.more_time),
                  title: const Text('Horas extra de la semana', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    p.horasExtraTotal > 0
                        ? '${p.horasExtraTotal.toStringAsFixed(1).replaceAll('.', ',')} h hoy · programar'
                        : 'Programar por persona y día',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/gerencia/horas-extra'),
                ),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: const Text('Energía de hoy', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${p.energiaKwh.toStringAsFixed(0)} kWh · ${pesos(p.energiaCosto)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/gerencia/energia'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
