import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/cache.dart';
import '../../core/formato.dart';
import 'modelos_operario.dart';

List<Map<String, dynamic>> _lista(dynamic datos) => [
  for (final item in (datos as List)) Map<String, dynamic>.from(item as Map),
];

Map<String, dynamic> _objeto(dynamic datos) => Map<String, dynamic>.from(datos as Map);

/// Lo que hace el operario contra el backend. El servidor valida rol y reglas;
/// aquí solo se arma la petición y se lee la respuesta.
class ApiOperario {
  ApiOperario(this._api);

  final ClienteApi _api;

  // ---- Alistamiento ----

  /// Cola de alistamiento (más antiguos primero, como los entrega el servidor).
  Future<List<PedidoResumen>> cola() async =>
      _lista(await _api.get('/pedidos', parametros: {'estado': 'registrado'})).map(PedidoResumen.fromJson).toList();

  /// Pedidos que esta persona ya tomó y está alistando.
  Future<List<PedidoResumen>> alistando() async => _lista(
    await _api.get('/pedidos', parametros: {'estado': 'alistando', 'mios': true}),
  ).map(PedidoResumen.fromJson).toList();

  Future<Pedido> pedido(int id) async => Pedido.fromJson(_objeto(await _api.get('/pedidos/$id')));

  Future<Pedido> tomar(int id) async => Pedido.fromJson(_objeto(await _api.post('/pedidos/$id/tomar')));

  Future<Pedido> listoParaEnvio(int id, ConteoAlistamiento conteo) async =>
      Pedido.fromJson(_objeto(await _api.post('/pedidos/$id/listo', datos: conteo.cuerpoListo())));

  // ---- Recepción ----

  Future<List<Compra>> comprasPorRecibir() async =>
      _lista(await _api.get('/compras', parametros: {'estado': 'aprobada'})).map(Compra.fromJson).toList();

  Future<Compra> compra(int id) async => Compra.fromJson(_objeto(await _api.get('/compras/$id')));

  Future<Compra> recibir(int id, {required int buenas, required int danadas}) async => Compra.fromJson(
    _objeto(await _api.post('/compras/$id/recibir', datos: {'cantidad_buena': buenas, 'cantidad_danada': danadas})),
  );

  // ---- Jornada ----

  Future<JornadaHoy> jornadaHoy() async => JornadaHoy.fromJson(_objeto(await _api.get('/jornada/hoy')));

  /// Las horas extra propias (el servidor solo devuelve las de esta persona).
  Future<List<HoraExtra>> horasExtra() async {
    final lista = _lista(await _api.get('/horas-extra')).map(HoraExtra.fromJson).toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  Future<HoraExtra> solicitarHoraExtra({
    required DateTime fecha,
    required int horas,
    required int minutos,
    required MotivoHoraExtra motivo,
  }) async => HoraExtra.fromJson(
    _objeto(
      await _api.post(
        '/horas-extra/solicitar',
        datos: {'fecha': fechaApi(fecha), 'hora_fin': horaApi(horas, minutos), 'motivo': motivo.valor},
      ),
    ),
  );
}

final apiOperarioProvider = Provider<ApiOperario>((ref) => ApiOperario(ref.watch(clienteApiProvider)));

// ---- Datos que leen las pantallas (se recargan con ref.invalidate) ----

final colaProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiOperarioProvider).cola();
});

final alistandoProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiOperarioProvider).alistando();
});

final pedidoProvider = FutureProvider.autoDispose.family<Pedido, int>(
  (ref, id) => ref.watch(apiOperarioProvider).pedido(id),
);

final comprasPorRecibirProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiOperarioProvider).comprasPorRecibir();
});

final compraProvider = FutureProvider.autoDispose.family<Compra, int>(
  (ref, id) => ref.watch(apiOperarioProvider).compra(id),
);

final jornadaHoyProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiOperarioProvider).jornadaHoy();
});

final horasExtraProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiOperarioProvider).horasExtra();
});

/// Lo escaneado en cada pedido (producto → unidades). Se guarda en memoria para
/// no perder la cuenta si el operario sale de la pantalla y vuelve.
final progresoAlistamientoProvider = Provider<Map<int, Map<int, int>>>((ref) => {});

/// Recarga todo lo que muestra el operario (después de tomar, alistar o recibir).
void recargarOperario(WidgetRef ref) {
  ref.invalidate(colaProvider);
  ref.invalidate(alistandoProvider);
  ref.invalidate(comprasPorRecibirProvider);
}
