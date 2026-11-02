import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/aviso_salida.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_operario.dart';

/// Inicio del operario, «Mis tareas»: lo que estoy alistando arriba y la cola
/// (más antiguos primero) abajo, más el acceso a la mercancía por recibir.
class PantallaTareas extends ConsumerStatefulWidget {
  const PantallaTareas({super.key});

  @override
  ConsumerState<PantallaTareas> createState() => _PantallaTareasState();
}

class _PantallaTareasState extends ConsumerState<PantallaTareas> {
  /// Pedido que se está tomando (para mostrar la carga en su botón).
  int? _tomando;

  Future<void> _recargar() async {
    recargarOperario(ref);
    ref.invalidate(jornadaHoyProvider);
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
    final compras = ref.watch(comprasPorRecibirProvider).valueOrNull;
    final jornada = ref.watch(jornadaHoyProvider).valueOrNull;
    final progreso = ref.watch(progresoAlistamientoProvider);

    return EsqueletoRol(
      titulo: 'Mis tareas',
      chip: jornada == null
          ? null
          : ChipEncabezado(
              icono: Icons.schedule,
              texto: 'Jornada ${horaCorta(jornada.horaInicio)} a ${horaCorta(jornada.horaSalida)}',
            ),
      alRecargar: _recargar,
      hijos: [
        const AvisoSalida(),
        VistaAsync(
          valor: alistando,
          alReintentar: _recargar,
          datos: (lista) => Column(
            children: [
              for (final pedido in lista)
                _TarjetaAlistando(
                  pedido: pedido,
                  escaneadas: progreso[pedido.id]?.values.fold<int>(0, (a, b) => a + b) ?? 0,
                  onTap: () => _abrir(pedido.id),
                ),
            ],
          ),
        ),
        VistaAsync(
          valor: cola,
          alReintentar: _recargar,
          datos: (lista) => lista.isEmpty
              ? const ListaVacia(icono: Icons.check_circle_outline, texto: 'No hay pedidos en cola.')
              : Column(
                  children: [
                    for (final pedido in lista)
                      _TarjetaCola(
                        pedido: pedido,
                        tomando: _tomando == pedido.id,
                        habilitado: _tomando == null,
                        onTomar: () => _tomar(pedido),
                      ),
                  ],
                ),
        ),
        if (compras != null && compras.isNotEmpty)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/operario/recepcion'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: ColoresNovaTech.naranja),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recibir mercancía', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${compras.length} ${compras.length == 1 ? 'compra aprobada' : 'compras aprobadas'}',
                            style: const TextStyle(color: ColoresNovaTech.textoSuave),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: ColoresNovaTech.textoSuave),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// «PED-0412 · Registrado · 5 unidades · Tomar tarea».
class _TarjetaCola extends StatelessWidget {
  const _TarjetaCola({
    required this.pedido,
    required this.tomando,
    required this.habilitado,
    required this.onTomar,
  });

  final PedidoResumen pedido;
  final bool tomando;
  final bool habilitado;
  final VoidCallback onTomar;

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(pedido.codigo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const Insignia(texto: 'Registrado', color: ColoresNovaTech.naranja),
              ],
            ),
            const SizedBox(height: 2),
            Text(detalles.join(' · '), style: const TextStyle(color: ColoresNovaTech.textoSuave)),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: habilitado ? onTomar : null,
              child: tomando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Tomar tarea'),
            ),
          ],
        ),
      ),
    );
  }
}

/// «PED-0409 · Alistando · Escaneadas 2 de 4» con barra de avance.
class _TarjetaAlistando extends StatelessWidget {
  const _TarjetaAlistando({required this.pedido, required this.escaneadas, required this.onTap});

  final PedidoResumen pedido;
  final int escaneadas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = pedido.unidades;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(pedido.codigo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  const Insignia(texto: 'Alistando', color: ColoresNovaTech.azul),
                ],
              ),
              const SizedBox(height: 2),
              Text('Escaneadas $escaneadas de $total', style: const TextStyle(color: ColoresNovaTech.textoSuave)),
              const SizedBox(height: 8),
              BarraAvance(valor: total == 0 ? 0 : escaneadas / total),
            ],
          ),
        ),
      ),
    );
  }
}
