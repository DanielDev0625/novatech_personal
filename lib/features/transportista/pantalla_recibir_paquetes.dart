import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/ubicacion.dart';
import '../../core/widgets/escaner.dart';
import '../../core/widgets/vista_async.dart';
import 'api_transportista.dart';
import 'modelos_transportista.dart';

/// Paquetes en la zona de envíos. Al recibir uno se escanea su QR (traspaso de custodia).
class PantallaRecibirPaquetes extends ConsumerStatefulWidget {
  const PantallaRecibirPaquetes({super.key});

  @override
  ConsumerState<PantallaRecibirPaquetes> createState() => _PantallaRecibirPaquetesState();
}

class _PantallaRecibirPaquetesState extends ConsumerState<PantallaRecibirPaquetes> {
  bool _enviando = false;

  Future<void> _recargar() async {
    ref.invalidate(zonaEnviosProvider);
    try {
      await ref.read(zonaEnviosProvider.future);
    } catch (_) {
      // El error se ve en la lista.
    }
  }

  Future<void> _escanear() async {
    final codigo = await escanearCodigo(
      context,
      titulo: 'Recibir paquete',
      instruccion: 'Apunta al QR pegado en el paquete.',
    );
    if (codigo == null || !mounted) return;

    final pedidos = ref.read(zonaEnviosProvider).valueOrNull ?? const [];
    final pedido = pedidoDeCodigo(pedidos, codigo);
    if (pedido == null) {
      mostrarMensaje(context, 'El paquete $codigo no está en la zona de envíos.', error: true);
      await _recargar();
      return;
    }

    setState(() => _enviando = true);
    try {
      final posicion = await ubicacionActual();
      await ref.read(apiTransportistaProvider).recibirPaquete(pedido.id, codigo, posicion);
      if (!mounted) return;
      mostrarMensaje(context, 'Recibiste el paquete ${pedido.codigo}. Ya está en tu ruta.');
      ref.invalidate(rutaProvider);
      await _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
      await _recargar();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(zonaEnviosProvider);
    final hay = pedidos.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Recibir paquetes')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const TituloSeccion('En la zona de envíos'),
                  VistaAsync(
                    valor: pedidos,
                    alReintentar: _recargar,
                    datos: (lista) => lista.isEmpty
                        ? const ListaVacia(
                            icono: Icons.inventory_2_outlined,
                            texto: 'No hay paquetes esperando. Jala hacia abajo para revisar de nuevo.',
                          )
                        : Column(
                            children: [
                              for (final pedido in lista)
                                Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.inventory_2_outlined),
                                    title: Text(pedido.codigo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    subtitle: Text([
                                      if (pedido.cliente != null) pedido.cliente!,
                                      '${pedido.unidades} ${pedido.unidades == 1 ? 'unidad' : 'unidades'}',
                                      if (pedido.fechaPrometida != null)
                                        'entrega ${diaRelativo(pedido.fechaPrometida!)}',
                                    ].join(' · ')),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                onPressed: hay && !_enviando ? _escanear : null,
                icon: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear paquete'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
