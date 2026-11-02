import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/ubicacion.dart';
import '../../core/widgets/adaptable.dart';
import '../../core/widgets/escaner.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_transportista.dart';
import 'modelos_transportista.dart';
import 'pantalla_ruta.dart';

/// A cuántos metros de la dirección guardada se considera que se está en el lugar.
const metrosCercaDeLaDireccion = 300.0;

/// Confirmar entrega: se escanea el QR que muestra el cliente en su app.
class PantallaEntregar extends ConsumerWidget {
  const PantallaEntregar({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruta = ref.watch(rutaProvider);
    return Scaffold(
      appBar: barraNovaTech(titulo: 'Confirmar entrega'),
      body: ContenidoCentrado(
        child: VistaAsync(
          valor: ruta,
          alReintentar: () => ref.invalidate(rutaProvider),
          datos: (datos) {
            final parada = datos.paradas.where((p) => p.pedidoId == pedidoId).firstOrNull;
            if (parada == null || !parada.enRuta) {
              return const ListaVacia(
                icono: Icons.info_outline,
                texto: 'Este pedido ya no está en ruta. Vuelve a tus entregas.',
              );
            }
            return _Entrega(parada: parada);
          },
        ),
      ),
    );
  }
}

class _Entrega extends ConsumerStatefulWidget {
  const _Entrega({required this.parada});

  final Parada parada;

  @override
  ConsumerState<_Entrega> createState() => _EntregaState();
}

class _EntregaState extends ConsumerState<_Entrega> {
  Punto? _posicion;
  bool _buscandoGps = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _ubicar();
  }

  Future<void> _ubicar() async {
    final posicion = await ubicacionActual();
    if (!mounted) return;
    setState(() {
      _posicion = posicion;
      _buscandoGps = false;
    });
  }

  /// Un QR rechazado no se vuelve a enviar mientras siga frente a la cámara.
  String? _ultimoRechazado;
  DateTime _horaRechazo = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _alLeer(String qr) async {
    if (_enviando) return;
    if (qr == _ultimoRechazado && DateTime.now().difference(_horaRechazo).inSeconds < 4) return;
    setState(() => _enviando = true);
    HapticFeedback.mediumImpact();
    final parada = widget.parada;
    try {
      await ref.read(apiTransportistaProvider).entregar(parada.pedidoId, qr, _posicion ?? await ubicacionActual());
      ref.invalidate(rutaProvider);
      ref.invalidate(liquidacionProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (contexto) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: ColoresNovaTech.verde, size: 56),
          title: const Text('Pedido entregado'),
          content: Text(
            '${parada.codigo} quedó entregado a ${parada.cliente.isEmpty ? 'el cliente' : parada.cliente}.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(contexto),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      // QR equivocado, pedido de otra persona, etc.: el servidor dice qué pasó.
      _ultimoRechazado = qr;
      _horaRechazo = DateTime.now();
      if (mounted) {
        mostrarMensaje(context, errorDesde(e).mensaje, error: true);
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parada = widget.parada;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${parada.codigo} · Parada ${parada.orden}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  [parada.direccion.texto, if (parada.cliente.isNotEmpty) parada.cliente].join(' · '),
                  style: const TextStyle(color: ColoresNovaTech.textoSuave),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              VistaCamara(alto: 300, alLeer: _alLeer),
              if (_enviando)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text('Escanea el QR que muestra el cliente', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
        const SizedBox(height: 12),
        _EstadoGps(
          buscando: _buscandoGps,
          posicion: _posicion,
          parada: parada,
          onReintentar: () {
            setState(() => _buscandoGps = true);
            _ubicar();
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => navegarA(context, parada),
          icon: const Icon(Icons.navigation_outlined),
          label: const Text('Cómo llegar'),
        ),
      ],
    );
  }
}

class _EstadoGps extends StatelessWidget {
  const _EstadoGps({required this.buscando, required this.posicion, required this.parada, required this.onReintentar});

  final bool buscando;
  final Punto? posicion;
  final Parada parada;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final (icono, color, texto) = switch (posicion) {
      _ when buscando => (Icons.gps_not_fixed, ColoresNovaTech.textoSuave, 'Buscando tu ubicación…'),
      null => (Icons.location_disabled, ColoresNovaTech.naranja, 'Sin GPS: la entrega se registra sin ubicación.'),
      final p => () {
        final metros = p.metrosHasta(parada.direccion.latitud, parada.direccion.longitud);
        return metros <= metrosCercaDeLaDireccion
            ? (Icons.where_to_vote_outlined, ColoresNovaTech.verde, 'GPS coincide con la dirección guardada')
            : (
                Icons.wrong_location_outlined,
                ColoresNovaTech.naranja,
                'Estás a ${distancia(metros / 1000)} de la dirección guardada',
              );
      }(),
    };
    return Card(
      child: ListTile(
        leading: Icon(icono, color: color),
        title: Text(texto),
        trailing: buscando
            ? null
            : IconButton(tooltip: 'Actualizar ubicación', onPressed: onReintentar, icon: const Icon(Icons.refresh)),
      ),
    );
  }
}
