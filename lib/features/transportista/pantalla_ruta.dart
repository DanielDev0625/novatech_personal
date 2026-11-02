import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/ubicacion.dart';
import '../../core/widgets/escaner.dart';
import '../../core/widgets/vista_async.dart';
import 'api_transportista.dart';
import 'modelos_transportista.dart';

/// «Mi ruta»: mapa y paradas en el orden más eficiente. Desde aquí se inicia la
/// ruta y se confirma cada entrega escaneando el QR que muestra el cliente.
class PantallaRuta extends ConsumerStatefulWidget {
  const PantallaRuta({super.key});

  @override
  ConsumerState<PantallaRuta> createState() => _PantallaRutaState();
}

class _PantallaRutaState extends ConsumerState<PantallaRuta> {
  /// Acción en curso (iniciar ruta o entregar un pedido) para bloquear botones.
  bool _ocupado = false;

  Future<void> _recargar() async {
    ref.invalidate(rutaProvider);
    try {
      await ref.read(rutaProvider.future);
    } catch (_) {
      // El error se ve en pantalla.
    }
  }

  Future<void> _accion(Future<void> Function() hacer) async {
    setState(() => _ocupado = true);
    try {
      await hacer();
    } catch (e) {
      if (mounted) mostrarMensaje(context, errorDesde(e).mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
      await _recargar();
    }
  }

  Future<void> _iniciarRuta(Ruta ruta) async {
    final porSalir = ruta.paradas.where((p) => p.porSalir).length;
    final ok = await confirmar(
      context,
      titulo: 'Iniciar ruta',
      texto: 'Los $porSalir ${porSalir == 1 ? 'paquete pasa' : 'paquetes pasan'} a «en ruta» y tus '
          'clientes empezarán a ver por dónde vas.',
      aceptar: 'Iniciar',
    );
    if (!ok || !mounted) return;
    await _accion(() async {
      await ref.read(apiTransportistaProvider).iniciarRuta(await ubicacionActual());
      if (mounted) mostrarMensaje(context, '¡Buen viaje! La ruta empezó.');
    });
  }

  Future<void> _entregar(Parada parada) async {
    final qr = await escanearCodigo(
      context,
      titulo: 'Entregar ${parada.codigo}',
      instruccion: 'Pide a ${parada.cliente.isEmpty ? 'el cliente' : parada.cliente} que te muestre '
          'el QR de entrega en su app.',
    );
    if (qr == null || !mounted) return;
    await _accion(() async {
      await ref.read(apiTransportistaProvider).entregar(parada.pedidoId, qr, await ubicacionActual());
      ref.invalidate(liquidacionProvider);
      if (mounted) mostrarMensaje(context, 'Pedido ${parada.codigo} entregado.');
    });
  }

  Future<void> _comoLlegar(Parada parada) async {
    final d = parada.direccion;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${d.latitud},${d.longitud}&travelmode=driving',
    );
    final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!abierto && mounted) mostrarMensaje(context, 'No se pudo abrir el mapa.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final ruta = ref.watch(rutaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi ruta')),
      body: VistaAsync(
        valor: ruta,
        alReintentar: _recargar,
        datos: (datos) => datos.paradas.isEmpty
            ? RefreshIndicator(
                onRefresh: _recargar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    ListaVacia(
                      icono: Icons.map_outlined,
                      texto: 'No tienes entregas. Recibe paquetes en la zona de envíos para armar tu ruta.',
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  SizedBox(height: 230, child: _MapaRuta(ruta: datos)),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _recargar,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _ResumenRuta(ruta: datos),
                          if (datos.puedeIniciar) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _ocupado ? null : () => _iniciarRuta(datos),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Iniciar ruta'),
                            ),
                          ],
                          const SizedBox(height: 8),
                          for (final parada in datos.paradas)
                            _TarjetaParada(
                              parada: parada,
                              ocupado: _ocupado,
                              onComoLlegar: () => _comoLlegar(parada),
                              onEntregar: () => _entregar(parada),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MapaRuta extends StatelessWidget {
  const _MapaRuta({required this.ruta});

  final Ruta ruta;

  @override
  Widget build(BuildContext context) {
    final origen = LatLng(ruta.origenLatitud, ruta.origenLongitud);
    final paradas = [for (final p in ruta.paradas) LatLng(p.direccion.latitud, p.direccion.longitud)];
    final puntos = [origen, ...paradas];

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: puntos,
          padding: const EdgeInsets.all(36),
          maxZoom: 16,
        ),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.novatech.novatech_personal',
        ),
        PolylineLayer(
          polylines: [Polyline(points: puntos, strokeWidth: 4, color: ColoresNovaTech.azul)],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: origen,
              width: 36,
              height: 36,
              child: Icon(
                ruta.origenEsPosicionReal ? Icons.my_location : Icons.warehouse,
                color: ColoresNovaTech.marino,
                size: 30,
              ),
            ),
            for (final parada in ruta.paradas)
              Marker(
                point: LatLng(parada.direccion.latitud, parada.direccion.longitud),
                width: 32,
                height: 32,
                child: _NumeroParada(orden: parada.orden, enRuta: parada.enRuta),
              ),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}

class _NumeroParada extends StatelessWidget {
  const _NumeroParada({required this.orden, required this.enRuta});

  final int orden;
  final bool enRuta;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: enRuta ? ColoresNovaTech.naranja : ColoresNovaTech.azul,
      child: Text('$orden', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

class _ResumenRuta extends StatelessWidget {
  const _ResumenRuta({required this.ruta});

  final Ruta ruta;

  @override
  Widget build(BuildContext context) {
    final n = ruta.paradas.length;
    return Row(
      children: [
        const Icon(Icons.route, color: ColoresNovaTech.azul),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$n ${n == 1 ? 'parada' : 'paradas'} · ${distancia(ruta.totalKm)} · ${duracion(ruta.tiempoTotalMinutos)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (!ruta.origenEsPosicionReal)
          const Tooltip(
            message: 'Sin tu ubicación, la ruta se calcula desde la bodega.',
            child: Icon(Icons.info_outline, size: 20, color: Colors.black45),
          ),
      ],
    );
  }
}

class _TarjetaParada extends StatelessWidget {
  const _TarjetaParada({
    required this.parada,
    required this.ocupado,
    required this.onComoLlegar,
    required this.onEntregar,
  });

  final Parada parada;
  final bool ocupado;
  final VoidCallback onComoLlegar;
  final VoidCallback onEntregar;

  @override
  Widget build(BuildContext context) {
    final llegada = DateTime.now().add(Duration(minutes: parada.etaMinutos));
    final indicaciones = parada.direccion.indicaciones;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _NumeroParada(orden: parada.orden, enRuta: parada.enRuta),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(parada.codigo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (parada.cliente.isNotEmpty) Text(parada.cliente),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    parada.enRuta ? 'En ruta' : 'Por salir',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: parada.enRuta ? ColoresNovaTech.naranja : ColoresNovaTech.azul,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(parada.direccion.texto),
            if (indicaciones != null && indicaciones.isNotEmpty)
              Text(indicaciones, style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text(
              'A ${distancia(parada.distanciaKm)} · llegada aprox. ${hora(llegada)}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: onComoLlegar,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Cómo llegar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: ColoresNovaTech.verde,
                    ),
                    // Solo se entrega lo que ya va en ruta.
                    onPressed: parada.enRuta && !ocupado ? onEntregar : null,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Entregar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
