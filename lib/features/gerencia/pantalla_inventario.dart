import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_gerencia.dart';
import 'modelos_gerencia.dart';
import 'pantalla_energia.dart';

/// «Inventario» (gerente y administrador): todo el catálogo con stock, mínimo,
/// costo, precio y valor en bodega. Se filtra con toques, sin escribir.
class PantallaInventario extends ConsumerStatefulWidget {
  const PantallaInventario({super.key});

  @override
  ConsumerState<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends ConsumerState<PantallaInventario> {
  FiltroInventario _filtro = FiltroInventario.todos;
  String? _categoria;
  OrdenInventario _orden = OrdenInventario.nombre;

  Future<void> _recargar() async {
    ref.invalidate(inventarioProvider);
    try {
      await ref.read(inventarioProvider.future);
    } catch (_) {
      // El error se ve en pantalla.
    }
  }

  void _verDetalle(ProductoInventario producto) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleProducto(producto: producto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventario = ref.watch(inventarioProvider);
    return EsqueletoRol(
      titulo: 'Inventario',
      alRecargar: _recargar,
      hijos: [
        VistaAsync(
          valor: inventario,
          alReintentar: _recargar,
          datos: (productos) {
            final activos = productos.where((p) => p.activo).toList();
            final bajos = activos.where((p) => p.stockBajo && !p.agotado).length;
            final agotados = activos.where((p) => p.agotado).length;
            final categorias = {for (final p in productos) p.categoria}.toList()..sort();
            final lista = filtrarInventario(productos, filtro: _filtro, categoria: _categoria, orden: _orden);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RejillaIndicadores(
                  indicadores: [
                    Indicador(
                      etiqueta: 'Productos',
                      valor: '${activos.length}',
                      detalle: categorias.length == 1 ? '1 categoría' : '${categorias.length} categorías',
                    ),
                    Indicador(etiqueta: 'Unidades', valor: entero(activos.fold<double>(0, (s, p) => s + p.stock))),
                    Indicador(
                      etiqueta: 'Valor en bodega',
                      valor: pesosCorto(activos.fold<double>(0, (s, p) => s + p.valor)),
                      detalle: 'a precio de costo',
                    ),
                    Indicador(
                      etiqueta: 'Stock bajo',
                      valor: '$bajos',
                      color: ColoresNovaTech.naranja,
                      detalle: agotados == 0
                          ? null
                          : agotados == 1
                          ? '1 agotado'
                          : '$agotados agotados',
                      onTap: () => setState(() => _filtro = FiltroInventario.stockBajo),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (filtro, texto) in [
                        (FiltroInventario.todos, 'Todos'),
                        (FiltroInventario.stockBajo, 'Stock bajo · $bajos'),
                        (FiltroInventario.agotados, 'Agotados · $agotados'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(texto),
                            selected: _filtro == filtro,
                            onSelected: (_) => setState(() => _filtro = filtro),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todas las categorías'),
                          selected: _categoria == null,
                          onSelected: (_) => setState(() => _categoria = null),
                        ),
                      ),
                      for (final c in categorias)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _categoria == c,
                            onSelected: (_) => setState(() => _categoria = _categoria == c ? null : c),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lista.length == 1 ? '1 producto' : '${lista.length} productos',
                        style: const TextStyle(color: ColoresNovaTech.textoSuave),
                      ),
                    ),
                    PopupMenuButton<OrdenInventario>(
                      initialValue: _orden,
                      onSelected: (o) => setState(() => _orden = o),
                      itemBuilder: (_) => [
                        for (final o in OrdenInventario.values) PopupMenuItem(value: o, child: Text(o.etiqueta)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 18, color: ColoresNovaTech.azul),
                            const SizedBox(width: 4),
                            Text(
                              _orden.etiqueta,
                              style: const TextStyle(color: ColoresNovaTech.azul, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (lista.isEmpty)
                  const ListaVacia(icono: Icons.inventory_2_outlined, texto: 'Ningún producto con estos filtros.')
                else
                  for (final p in lista) _TarjetaProducto(producto: p, onTap: () => _verDetalle(p)),
              ],
            );
          },
        ),
      ],
    );
  }
}

Color _colorStock(ProductoInventario p) => p.agotado
    ? ColoresNovaTech.rojo
    : p.stockBajo
    ? ColoresNovaTech.naranja
    : ColoresNovaTech.verde;

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({required this.producto, required this.onTap});

  final ProductoInventario producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: p.activo ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(
                        [if (p.marca?.isNotEmpty ?? false) p.marca!, p.sku].join(' · '),
                        style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Insignia(texto: p.categoria, color: ColoresNovaTech.azul),
                          if (!p.activo) const Insignia(texto: 'Inactivo', color: ColoresNovaTech.textoSuave),
                          if (p.agotado && p.activo) const Insignia(texto: 'Agotado', color: ColoresNovaTech.rojo),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${p.stock}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _colorStock(p)),
                    ),
                    Text(
                      'mín ${p.stockMinimo}',
                      style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(pesos(p.precio), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja con el detalle del producto y sus lotes.
class _DetalleProducto extends ConsumerWidget {
  const _DetalleProducto({required this.producto});

  final ProductoInventario producto;

  Widget _dato(String etiqueta, String valor, {Color? color}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
        Text(
          valor,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color ?? ColoresNovaTech.texto),
        ),
      ],
    ),
  );

  static (String, Color) _estadoLote(String estado) => switch (estado) {
    'recibido' => ('Recibido', ColoresNovaTech.azul),
    'almacenado' => ('Almacenado', ColoresNovaTech.verde),
    'agotado' => ('Agotado', ColoresNovaTech.textoSuave),
    _ => (estado, ColoresNovaTech.textoSuave),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = producto;
    final lotes = ref.watch(lotesProvider(p.id));
    final margen = p.margen;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(p.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            [if (p.marca?.isNotEmpty ?? false) p.marca!, 'SKU ${p.sku}', p.categoria].join(' · '),
            style: const TextStyle(color: ColoresNovaTech.textoSuave),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _dato('Stock', '${p.stock}', color: _colorStock(p)),
              _dato('Mínimo', '${p.stockMinimo}'),
              _dato('Valor en bodega', pesosCorto(p.valor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _dato('Costo', pesos(p.costo)),
              _dato('Precio', pesos(p.precio)),
              _dato('Margen', margen == null ? '—' : '${(margen * 100).round()}%'),
            ],
          ),
          if (p.stockMinimo > 0) ...[
            const SizedBox(height: 14),
            BarraAvance(valor: p.stock / (p.stockMinimo * 2), color: _colorStock(p)),
            const SizedBox(height: 4),
            Text(
              p.agotado
                  ? 'Sin unidades disponibles.'
                  : p.stockBajo
                  ? 'Por debajo del mínimo: faltan ${p.stockMinimo - p.stock} para llegar a él.'
                  : 'Stock suficiente.',
              style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
            ),
          ],
          const TituloSeccion('Lotes'),
          VistaAsync(
            valor: lotes,
            alReintentar: () => ref.invalidate(lotesProvider(p.id)),
            datos: (lista) => lista.isEmpty
                ? const ListaVacia(icono: Icons.inventory_outlined, texto: 'Este producto aún no tiene lotes.')
                : Column(
                    children: [
                      for (final lote in lista)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(lote.codigo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    Insignia(texto: _estadoLote(lote.estado).$1, color: _estadoLote(lote.estado).$2),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${lote.cantidadRestante} de ${lote.cantidadInicial} unidades · '
                                  'costo ${pesos(lote.costoUnitario)}',
                                ),
                                Text(
                                  [
                                    if (lote.proveedor?.isNotEmpty ?? false) lote.proveedor!,
                                    if (lote.fechaRecepcion != null) 'recibido el ${fechaCorta(lote.fechaRecepcion!)}',
                                  ].join(' · '),
                                  style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                BarraAvance(
                                  valor: lote.cantidadInicial == 0 ? 0 : lote.cantidadRestante / lote.cantidadInicial,
                                  color: ColoresNovaTech.azul,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
