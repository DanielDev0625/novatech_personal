import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_gerencia.dart';
import 'modelos_gerencia.dart';

/// Colores de las barras, en el orden de la marca.
const coloresGrafico = [
  ColoresNovaTech.rojo,
  ColoresNovaTech.naranja,
  ColoresNovaTech.verde,
  ColoresNovaTech.azul,
  ColoresNovaTech.marino,
];

String porcentaje(double valor) => '${valor.toStringAsFixed(valor >= 10 ? 0 : 1).replaceAll('.', ',')}%';

/// «Estadísticas» (gerente y administrador): ventas, entregas y stock por semana o mes.
class PantallaEstadisticas extends ConsumerStatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  ConsumerState<PantallaEstadisticas> createState() => _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends ConsumerState<PantallaEstadisticas> {
  Periodo _periodo = Periodo.semana;

  Future<void> _recargar() async {
    ref.invalidate(estadisticasProvider(_periodo));
    try {
      await ref.read(estadisticasProvider(_periodo).future);
    } catch (_) {
      // El error se ve en pantalla.
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadisticas = ref.watch(estadisticasProvider(_periodo));
    return EsqueletoRol(
      titulo: 'Estadísticas',
      alRecargar: _recargar,
      hijos: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<Periodo>(
            showSelectedIcon: false,
            segments: [for (final p in Periodo.values) ButtonSegment(value: p, label: Text(p.etiqueta))],
            selected: {_periodo},
            onSelectionChanged: (s) => setState(() => _periodo = s.first),
          ),
        ),
        const SizedBox(height: 10),
        VistaAsync(
          valor: estadisticas,
          alReintentar: _recargar,
          datos: (e) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MasVendido(producto: e.masVendido),
              _Categorias(estadisticas: e),
              _Entregas(entregas: e.entregas),
              _StockBajo(estadisticas: e),
            ],
          ),
        ),
      ],
    );
  }
}

class _MasVendido extends StatelessWidget {
  const _MasVendido({required this.producto});

  final ProductoVenta? producto;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.emoji_events_outlined, color: ColoresNovaTech.naranja, size: 32),
        title: const Text('Más vendido', style: TextStyle(color: ColoresNovaTech.textoSuave)),
        subtitle: Text(
          p == null ? 'Sin ventas en este período' : '${p.nombre} · ${p.unidades} uds',
          style: const TextStyle(fontWeight: FontWeight.w800, color: ColoresNovaTech.texto, fontSize: 15),
        ),
      ),
    );
  }
}

class _Categorias extends StatelessWidget {
  const _Categorias({required this.estadisticas});

  final Estadisticas estadisticas;

  @override
  Widget build(BuildContext context) {
    final categorias = estadisticas.categorias;
    final mayor = categorias.isEmpty ? 0.0 : categorias.first.ingresos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Ventas por categoría', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(pesos(estadisticas.totalIngresos), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            if (categorias.isEmpty)
              const Text('Sin ventas en este período.', style: TextStyle(color: ColoresNovaTech.textoSuave))
            else
              for (final (i, c) in categorias.indexed)
                FilaBarra(
                  etiqueta: c.categoria,
                  proporcion: mayor == 0 ? 0 : c.ingresos / mayor,
                  valor: porcentaje(c.porcentaje),
                  color: coloresGrafico[i % coloresGrafico.length],
                ),
          ],
        ),
      ),
    );
  }
}

class _Entregas extends StatelessWidget {
  const _Entregas({required this.entregas});

  final EstadisticaEntregas entregas;

  @override
  Widget build(BuildContext context) {
    final pct = entregas.porcentajeATiempo;
    final retraso = entregas.retrasoPromedioHoras;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Entregas a tiempo')),
                Text(pct == null ? '—' : porcentaje(pct), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: entregas.entregadas == 0
                    ? const ColoredBox(color: ColoresNovaTech.borde)
                    : Row(
                        children: [
                          Expanded(flex: entregas.aTiempo, child: const ColoredBox(color: ColoresNovaTech.verde)),
                          Expanded(flex: entregas.tardias, child: const ColoredBox(color: ColoresNovaTech.rojo)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                '${entregas.entregadas} entregadas',
                if (entregas.tardias > 0) '${entregas.tardias} tardías',
                if (retraso != null && entregas.tardias > 0)
                  'retraso promedio ${retraso.toStringAsFixed(1).replaceAll('.', ',')} h',
              ].join(' · '),
              style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
            ),
            for (final etapa in entregas.etapas)
              if (etapa.promedioMinutos != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_mayuscula(etapa.etapa.replaceAll('_', ' '))}: ${duracion(etapa.promedioMinutos!.round())}'
                    '${etapa.esperadoMinutos != null ? ' (esperado ${duracion(etapa.esperadoMinutos!)})' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _mayuscula(String texto) => texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';

class _StockBajo extends StatelessWidget {
  const _StockBajo({required this.estadisticas});

  final Estadisticas estadisticas;

  @override
  Widget build(BuildContext context) {
    final lista = estadisticas.stockBajo;
    final pendientes = estadisticas.reposicionesPendientes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Stock bajo', style: TextStyle(color: ColoresNovaTech.textoSuave)),
              TextSpan(
                text: ' · ${lista.length} ${lista.length == 1 ? 'producto' : 'productos'}'
                    ' · $pendientes ${pendientes == 1 ? 'reposición pendiente' : 'reposiciones pendientes'}',
              ),
            ])),
            for (final s in lista.take(5))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(s.nombre, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(
                      '${s.stock} / ${s.stockMinimo}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresNovaTech.naranja),
                    ),
                    if (s.compra != null) ...[
                      const SizedBox(width: 8),
                      Insignia(texto: s.compra!, color: ColoresNovaTech.azul),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
