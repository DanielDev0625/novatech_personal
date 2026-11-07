import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/tema/tema.dart';
import '../../core/ubicacion.dart';
import '../../core/widgets/aviso_salida.dart';
import '../../core/widgets/codigo_qr.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/escaner.dart';
import '../../core/widgets/scaffold_rol.dart';
import '../../core/widgets/vista_async.dart';
import 'api_transportista.dart';
import 'modelos_transportista.dart';

/// Inicio del transportista, «Entregas de hoy»: las paradas en orden, los paquetes
/// que esperan en la zona de envíos, «Recibir paquete» e «Iniciar ruta».
class PantallaEntregas extends ConsumerStatefulWidget {
  const PantallaEntregas({super.key});

  @override
  ConsumerState<PantallaEntregas> createState() => _PantallaEntregasState();
}

class _PantallaEntregasState extends ConsumerState<PantallaEntregas> {
  bool _ocupado = false;

  Future<void> _recargar() async {
    ref.invalidate(zonaEnviosProvider);
    ref.invalidate(rutaProvider);
    try {
      await Future.wait([ref.read(zonaEnviosProvider.future), ref.read(rutaProvider.future)]);
    } catch (_) {
      // El error se ve en la lista.
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

  /// Traspaso de custodia: se escanea el QR pegado en el paquete.
  Future<void> _recibirPaquete() async {
    final codigo = await escanearCodigo(
      context,
      titulo: 'Recibir paquete',
      instruccion: 'Apunta al QR pegado en el paquete.',
    );
    if (codigo == null || !mounted) return;

    final pedidos = ref.read(zonaEnviosProvider).valueOrNull ?? const <PedidoResumen>[];
    final pedido = pedidoDeCodigo(pedidos, codigo);
    if (pedido == null) {
      mostrarMensaje(context, 'El paquete $codigo no está en la zona de envíos.', error: true);
      await _recargar();
      return;
    }
    await _recibir(pedido);
  }

  /// Sin etiqueta impresa: al tocar el paquete aparece su QR en pantalla con quién lo empacó,
  /// y un botón lo recibe y lo pasa a la ruta.
  Future<void> _recibirSinEscanear(PedidoResumen pedido) async {
    final api = ref.read(apiTransportistaProvider);
    final ok = await mostrarCodigoQr(
      context,
      titulo: 'Recibir paquete',
      codigo: pedido.codigo,
      detalles: [
        if (pedido.cliente != null) 'Cliente: ${pedido.cliente}',
        '${pedido.unidades} ${pedido.unidades == 1 ? 'unidad' : 'unidades'}',
      ],
      extra: _EmpacadoPor(nombre: api.empacadoPor(pedido.id)),
      accion: 'Recibir y continuar con mi ruta',
      iconoAccion: Icons.local_shipping_outlined,
    );
    if (ok != true || !mounted) return;
    await _recibir(pedido);
  }

  Future<void> _recibir(PedidoResumen pedido) async {
    await _accion(() async {
      await ref.read(apiTransportistaProvider).recibirPaquete(pedido.id, pedido.codigo, await ubicacionActual());
      if (mounted) mostrarMensaje(context, 'Recibiste el paquete ${pedido.codigo}. Ya está en tu ruta.');
    });
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

  @override
  Widget build(BuildContext context) {
    // Con entregas en ruta, la app comparte la ubicación para el seguimiento del cliente.
    ref.listen(rutaProvider, (_, ruta) {
      ruta.whenData((r) => ref.read(compartirUbicacionProvider.notifier).activar(r.hayEnRuta));
    });

    final ruta = ref.watch(rutaProvider);
    final zona = ref.watch(zonaEnviosProvider);
    final compartiendo = ref.watch(compartirUbicacionProvider);
    final puedeIniciar = ruta.valueOrNull?.puedeIniciar ?? false;

    return EsqueletoRol(
      titulo: 'Entregas de hoy',
      alRecargar: _recargar,
      accionInferior: puedeIniciar
          ? FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ColoresNovaTech.verde),
              onPressed: _ocupado ? null : () => _iniciarRuta(ruta.requireValue),
              child: const Text('Iniciar ruta'),
            )
          : null,
      hijos: [
        const AvisoSalida(),
        if (compartiendo)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Insignia(
              texto: 'Compartiendo tu ubicación con tus clientes',
              color: ColoresNovaTech.verde,
              icono: Icons.my_location,
            ),
          ),
        VistaAsync(
          valor: ruta,
          alReintentar: _recargar,
          datos: (datos) => Column(
            children: [
              for (final parada in datos.paradas)
                _FilaEntrega(
                  numero: '${parada.orden}',
                  codigo: parada.codigo,
                  direccion: parada.totalAPagar > 0
                      ? '${parada.direccion.texto} · Cobrar ${pesos(parada.totalAPagar)}'
                      : parada.direccion.texto,
                  estado: parada.enRuta
                      ? const Insignia(texto: 'En ruta', color: ColoresNovaTech.azul)
                      : const Insignia(texto: 'Por salir', color: ColoresNovaTech.verde),
                  onTap: parada.enRuta ? () => context.push('/transportista/entregar/${parada.pedidoId}') : null,
                ),
            ],
          ),
        ),
        VistaAsync(
          valor: zona,
          alReintentar: _recargar,
          datos: (lista) => Column(
            children: [
              for (final pedido in lista)
                _FilaEntrega(
                  numero: null,
                  codigo: pedido.codigo,
                  direccion: [
                    if (pedido.cliente != null) pedido.cliente!,
                    '${pedido.unidades} ${pedido.unidades == 1 ? 'unidad' : 'unidades'}',
                  ].join(' · '),
                  estado: const Insignia(texto: 'Por recibir', color: ColoresNovaTech.naranja),
                  onTap: _ocupado ? null : () => _recibirSinEscanear(pedido),
                ),
            ],
          ),
        ),
        if ((ruta.valueOrNull?.paradas.isEmpty ?? false) && (zona.valueOrNull?.isEmpty ?? false))
          const ListaVacia(
            icono: Icons.local_shipping_outlined,
            texto: 'Aún no hay entregas. Cuando un operario deje paquetes en la zona de envíos aparecerán aquí.',
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _ocupado || (zona.valueOrNull?.isEmpty ?? true) ? null : _recibirPaquete,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Recibir paquete (escanear QR)'),
        ),
        if (zona.valueOrNull?.isNotEmpty ?? false)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Toca un paquete para ver su QR y recibirlo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

/// «Empacado por Laura Pérez»: se consulta al abrir el paquete (una sola petición).
class _EmpacadoPor extends StatelessWidget {
  const _EmpacadoPor({required this.nombre});

  final Future<String?> nombre;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: nombre,
      builder: (context, foto) {
        final texto = switch (foto) {
          AsyncSnapshot(connectionState: ConnectionState.waiting) => 'Buscando quién lo empacó…',
          AsyncSnapshot(hasData: true, :final data?) => 'Empacado por $data',
          _ => null,
        };
        if (texto == null) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined, color: ColoresNovaTech.naranja),
            title: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }
}

class _FilaEntrega extends StatelessWidget {
  const _FilaEntrega({
    required this.numero,
    required this.codigo,
    required this.direccion,
    required this.estado,
    this.onTap,
  });

  /// Orden de la parada; null para los paquetes que aún no se reciben.
  final String? numero;
  final String codigo;
  final String direccion;
  final Widget estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: numero == null ? ColoresNovaTech.borde : ColoresNovaTech.naranja,
                child: numero == null
                    ? const Icon(Icons.inventory_2_outlined, size: 15, color: ColoresNovaTech.textoSuave)
                    : Text(
                        numero!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(codigo, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      direccion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresNovaTech.textoSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              estado,
            ],
          ),
        ),
      ),
    );
  }
}
