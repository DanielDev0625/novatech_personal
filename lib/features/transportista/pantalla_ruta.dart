import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/adaptable.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_transportista.dart';
import 'modelos_transportista.dart';

/// Abre la navegación (Google Maps o el navegador) hacia la parada.
Future<void> navegarA(BuildContext context, Parada parada) async {
  final d = parada.direccion;
  final url = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${d.latitud},${d.longitud}&travelmode=driving',
  );
  final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!abierto && context.mounted) mostrarMensaje(context, 'No se pudo abrir el mapa.', error: true);
}

/// «Ruta»: mapa con las paradas en el orden más eficiente y la siguiente parada.
class PantallaRuta extends ConsumerWidget {
  const PantallaRuta({super.key});

  Future<void> _recargar(WidgetRef ref) async {
    ref.invalidate(rutaProvider);
    try {
      await ref.read(rutaProvider.future);
    } catch (_) {
      // El error se ve en pantalla.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruta = ref.watch(rutaProvider);
    final datos = ruta.valueOrNull;
    final n = datos?.paradas.length ?? 0;
    final siguiente = datos == null || datos.paradas.isEmpty
        ? null
        : datos.paradas.firstWhere((p) => p.enRuta, orElse: () => datos.paradas.first);

    return Scaffold(
      appBar: barraNovaTech(
        etiqueta: 'Transportista',
        titulo: n == 0 ? 'Ruta' : 'Ruta · $n ${n == 1 ? 'parada' : 'paradas'}',
        acciones: const [BotonCuenta()],
      ),
      body: VistaAsync(
        valor: ruta,
        alReintentar: () => _recargar(ref),
        datos: (datos) => datos.paradas.isEmpty
            ? RefreshIndicator(
                onRefresh: () => _recargar(ref),
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
            : _Disposicion(
                mapa: _MapaRuta(ruta: datos),
                lista: RefreshIndicator(
                  onRefresh: () => _recargar(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SiguienteParada(parada: siguiente!, ruta: datos),
                      const TituloSeccion('Todas las paradas'),
                      for (final parada in datos.paradas)
                        Card(
                          child: ListTile(
                            leading: _NumeroParada(orden: parada.orden, enRuta: parada.enRuta),
                            title: Text(parada.direccion.texto, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${parada.codigo} · ${duracion(parada.etaMinutos)}'),
                            trailing: parada.enRuta ? const Icon(Icons.qr_code_scanner) : null,
                            onTap: parada.enRuta
                                ? () => context.push('/transportista/entregar/${parada.pedidoId}')
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                accion: FilledButton.icon(
                  onPressed: () => navegarA(context, siguiente),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navegar'),
                ),
              ),
      ),
    );
  }
}

/// Celular: mapa arriba y paradas abajo. Escritorio: mapa grande a la izquierda y
/// paradas en una columna a la derecha.
class _Disposicion extends StatelessWidget {
  const _Disposicion({required this.mapa, required this.lista, required this.accion});

  final Widget mapa;
  final Widget lista;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    final panel = Column(
      children: [
        Expanded(child: lista),
        SafeArea(
          top: false,
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: accion),
        ),
      ],
    );
    if (esEscritorio(context)) {
      return Row(
        children: [
          Expanded(child: mapa),
          const VerticalDivider(width: 1, color: ColoresNovaTech.borde),
          SizedBox(width: 420, child: panel),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(height: 260, child: mapa),
        Expanded(child: panel),
      ],
    );
  }
}

class _SiguienteParada extends StatelessWidget {
  const _SiguienteParada({required this.parada, required this.ruta});

  final Parada parada;
  final Ruta ruta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Siguiente parada', style: TextStyle(color: ColoresNovaTech.textoSuave)),
            Text(parada.direccion.texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (parada.direccion.indicaciones?.isNotEmpty ?? false)
              Text(
                parada.direccion.indicaciones!,
                style: const TextStyle(color: ColoresNovaTech.textoSuave, fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 4),
                Text(duracion(parada.etaMinutos)),
                const Spacer(),
                const Icon(Icons.route, size: 18),
                const SizedBox(width: 4),
                Text(distancia(parada.distanciaKm)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ruta.origenEsPosicionReal
                  ? 'Orden optimizado desde tu ubicación · ${distancia(ruta.totalKm)} en total'
                  : 'Orden optimizado desde la bodega · ${distancia(ruta.totalKm)} en total',
              style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
            ),
            if (parada.enRuta) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresNovaTech.verde,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => context.push('/transportista/entregar/${parada.pedidoId}'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Confirmar entrega'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Insignia(texto: 'Inicia la ruta para poder entregar', color: ColoresNovaTech.naranja),
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
        initialCameraFit: CameraFit.coordinates(coordinates: puntos, padding: const EdgeInsets.all(40), maxZoom: 16),
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
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: ColoresNovaTech.verde,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            for (final parada in ruta.paradas)
              Marker(
                point: LatLng(parada.direccion.latitud, parada.direccion.longitud),
                width: 30,
                height: 30,
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
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enRuta ? ColoresNovaTech.naranja : ColoresNovaTech.rojo,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$orden',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}
