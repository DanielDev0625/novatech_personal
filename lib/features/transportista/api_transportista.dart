import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/cache.dart';
import '../../core/sesion/sesion.dart';
import '../../core/ubicacion.dart';
import 'modelos_transportista.dart';

List<Map<String, dynamic>> _lista(dynamic datos) => [
  for (final item in (datos as List)) Map<String, dynamic>.from(item as Map),
];

Map<String, dynamic> _objeto(dynamic datos) => Map<String, dynamic>.from(datos as Map);

/// Lo que hace el transportista contra el backend. Las posiciones son opcionales:
/// si no hay GPS, la acción se hace igual.
class ApiTransportista {
  ApiTransportista(this._api);

  final ClienteApi _api;

  /// Paquetes listos en la zona de envíos, esperando transportista.
  Future<List<PedidoResumen>> enZonaEnvios() async =>
      _lista(await _api.get('/pedidos', parametros: {'estado': 'en_zona_envios'})).map(PedidoResumen.fromJson).toList();

  /// Traspaso de custodia: el operario entrega el paquete y se escanea su QR.
  Future<void> recibirPaquete(int pedidoId, String codigo, Punto? posicion) async {
    await _api.post('/pedidos/$pedidoId/recibir-transportista', datos: {'codigo': codigo, ...?posicion?.toJson()});
  }

  Future<Ruta> ruta() async => Ruta.fromJson(_objeto(await _api.get('/logistica/ruta')));

  /// Todos los paquetes recibidos pasan a «en ruta» de una vez.
  Future<void> iniciarRuta(Punto? posicion) async {
    await _api.post('/logistica/iniciar-ruta', datos: posicion?.toJson() ?? {});
  }

  /// Confirma la entrega con el QR que muestra el cliente.
  Future<void> entregar(int pedidoId, String qr, Punto? posicion) async {
    await _api.post('/pedidos/$pedidoId/entregar', datos: {'qr': qr, ...?posicion?.toJson()});
  }

  Future<void> enviarPosicion(Punto posicion) async {
    await _api.post('/logistica/posicion', datos: posicion.toJson());
  }

  Future<ResumenLiquidacion> liquidacion() async =>
      ResumenLiquidacion.fromJson(_objeto(await _api.get('/liquidaciones/mias')));
}

final apiTransportistaProvider = Provider<ApiTransportista>((ref) => ApiTransportista(ref.watch(clienteApiProvider)));

final zonaEnviosProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiTransportistaProvider).enZonaEnvios();
});

final rutaProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiTransportistaProvider).ruta();
});

final liquidacionProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiTransportistaProvider).liquidacion();
});

void recargarTransportista(WidgetRef ref) {
  ref.invalidate(zonaEnviosProvider);
  ref.invalidate(rutaProvider);
  ref.invalidate(liquidacionProvider);
}

/// Mientras haya entregas en ruta, envía la posición cada 30 s para que el
/// cliente vea en su mapa por dónde va su pedido. Solo con la app abierta.
class CompartirUbicacion extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    // Al cerrar sesión (o al terminar la jornada) se deja de compartir.
    ref.listen(sesionProvider, (_, sesion) {
      if (!sesion.autenticado) activar(false);
    });
    return false;
  }

  void activar(bool activo) {
    if (activo == state) return;
    state = activo;
    _timer?.cancel();
    _timer = null;
    if (activo) {
      _enviar();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _enviar());
    }
  }

  Future<void> _enviar() async {
    final posicion = await ubicacionActual();
    if (posicion == null || !state) return;
    try {
      await ref.read(apiTransportistaProvider).enviarPosicion(posicion);
    } catch (_) {
      // Sin red un momento: se vuelve a intentar en el siguiente envío.
    }
  }
}

final compartirUbicacionProvider = NotifierProvider<CompartirUbicacion, bool>(CompartirUbicacion.new);
