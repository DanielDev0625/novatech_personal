import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';

/// «Mis tareas»: lo que estoy alistando arriba y la cola (más antiguos primero) abajo.
class PantallaTareas extends ConsumerStatefulWidget {
  const PantallaTareas({super.key});

  @override
  ConsumerState<PantallaTareas> createState() => _PantallaTareasState();
}

class _PantallaTareasState extends ConsumerState<PantallaTareas> {
  /// Pedido que se está tomando (para mostrar la carga en su botón).
  int? _tomando;

  Future<void> _recargar() async {
    ref.invalidate(colaProvider);
    ref.invalidate(alistandoProvider);
    try {
      await Future.wait([ref.read(colaProvider.future), ref.read(alistandoProvider.future)]);
    } catch (_) {
      // El error se ve en la lista.
    }
  }

  Future<void> _abrir(int pedidoId) async {
    await context.push('/operario/alistar/$pedidoId');
    if (mounted) await _recargar();
  }

  Future<void> _tomar(PedidoResumen pedido) async {
    setState(() => _tomando = pedido.id);
    try {
      await ref.read(apiOperarioProvider).tomar(pedido.id);
      if (!mounted) return;
      mostrarMensaje(context, 'Tomaste el pedido ${pedido.codigo}.');
      await _abrir(pedido.id);
    } catch (e) {
      if (!mounted) return;
      final error = errorDesde(e);
      // 409/400: otro operario lo tomó primero o ya cambió de estado.
      final yaTomado = error.codigo == 409 || error.codigo == 400;
      mostrarMensaje(
        context,
        yaTomado ? 'Otro operario tomó el pedido ${pedido.codigo} antes. ${error.mensaje}' : error.mensaje,
        error: true,
      );
      await _recargar();
    } finally {
      if (mounted) setState(() => _tomando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alistando = ref.watch(alistandoProvider);
    final cola = ref.watch(colaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis tareas')),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const TituloSeccion('Estoy alistando'),
            VistaAsync(
              valor: alistando,
              alReintentar: _recargar,
              datos: (lista) => lista.isEmpty
                  ? const ListaVacia(icono: Icons.inbox_outlined, texto: 'No tienes pedidos en alistamiento.')
                  : Column(
                      children: [
                        for (final pedido in lista)
                          _TarjetaPedido(
                            pedido: pedido,
                            resaltado: true,
                            accion: FilledButton.icon(
                              style: FilledButton.styleFrom(minimumSize: const Size(128, 44)),
                              onPressed: () => _abrir(pedido.id),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Continuar'),
                            ),
                          ),
                      ],
                    ),
            ),
            const TituloSeccion('Cola de alistamiento'),
            VistaAsync(
              valor: cola,
              alReintentar: _recargar,
              datos: (lista) => lista.isEmpty
                  ? const ListaVacia(icono: Icons.check_circle_outline, texto: 'No hay pedidos en cola.')
                  : Column(
                      children: [
                        for (final pedido in lista)
                          _TarjetaPedido(
                            pedido: pedido,
                            accion: FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
                              onPressed: _tomando == null ? () => _tomar(pedido) : null,
                              child: _tomando == pedido.id
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : const Text('Tomar'),
                            ),
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

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({required this.pedido, required this.accion, this.resaltado = false});

  final PedidoResumen pedido;
  final Widget accion;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final creado = pedido.creadoEn;
    final prometida = pedido.fechaPrometida;
    final detalles = [
      '${pedido.unidades} ${pedido.unidades == 1 ? 'unidad' : 'unidades'}',
      if (creado != null) antiguedad(creado),
      if (prometida != null) 'entrega ${diaRelativo(prometida)}',
    ];

    return Card(
      shape: resaltado
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: ColoresNovaTech.azul, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pedido.codigo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  if (pedido.cliente != null) Text(pedido.cliente!),
                  const SizedBox(height: 4),
                  Text(detalles.join(' · '), style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            accion,
          ],
        ),
      ),
    );
  }
}
