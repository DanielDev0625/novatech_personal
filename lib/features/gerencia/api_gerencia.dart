import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/cache.dart';
import '../../core/formato.dart';
import 'modelos_gerencia.dart';

List<Map<String, dynamic>> _lista(dynamic datos) => [
  for (final item in (datos as List)) Map<String, dynamic>.from(item as Map),
];

Map<String, dynamic> _objeto(dynamic datos) => Map<String, dynamic>.from(datos as Map);

Map<String, dynamic> _rango(DateTime desde, DateTime hasta) => {'desde': fechaApi(desde), 'hasta': fechaApi(hasta)};

/// Lo que hace gerencia contra el backend (el administrador también ve las estadísticas).
class ApiGerencia {
  ApiGerencia(this._api);

  final ClienteApi _api;

  Future<Panel> panel(DateTime desde, DateTime hasta) async =>
      Panel.fromJson(_objeto(await _api.get('/estadisticas/panel', parametros: _rango(desde, hasta))));

  Future<List<Compra>> compras(String estado) async =>
      _lista(await _api.get('/compras', parametros: {'estado': estado})).map(Compra.fromJson).toList();

  Future<List<Compra>> comprasAtrasadas() async =>
      _lista(await _api.get('/compras/atrasadas')).map(Compra.fromJson).toList();

  Future<void> aprobarCompra(int id) => _api.post('/compras/$id/aprobar', datos: {});

  Future<void> rechazarCompra(int id) => _api.post('/compras/$id/rechazar', datos: {});

  /// Recepción con diferencias: «aceptar» crea el lote con las buenas; «descartar» no entra nada.
  Future<void> resolverCompra(int id, {required bool aceptar}) =>
      _api.post('/compras/$id/resolver', datos: {'decision': aceptar ? 'aceptar' : 'descartar'});

  Future<List<HoraExtra>> horasExtra({EstadoHoraExtra? estado, DateTime? desde, DateTime? hasta}) async => _lista(
    await _api.get(
      '/horas-extra',
      parametros: {
        if (estado != null) 'estado': estado.name,
        if (desde != null) 'desde': fechaApi(desde),
        if (hasta != null) 'hasta': fechaApi(hasta),
      },
    ),
  ).map(HoraExtra.fromJson).toList();

  Future<void> aprobarHoraExtra(int id) => _api.post('/horas-extra/$id/aprobar');

  Future<void> rechazarHoraExtra(int id) => _api.post('/horas-extra/$id/rechazar');

  /// Programa horas extra ya aprobadas para varias personas y días con la misma hora de fin.
  Future<void> programarHorasExtra({
    required List<int> usuarios,
    required List<DateTime> fechas,
    required String horaFin,
  }) => _api.post(
    '/horas-extra/programar',
    datos: {
      'usuario_ids': usuarios,
      'fechas': [for (final f in fechas) fechaApi(f)],
      'hora_fin': horaFin,
    },
  );

  /// Personas con horario: operarios y transportistas.
  Future<List<HorarioPersona>> horarios() async =>
      _lista(await _api.get('/horarios')).map(HorarioPersona.fromJson).where((h) => h.rol.tieneJornada).toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));

  Future<List<TransportistaEstado>> transportistas() async =>
      _lista(await _api.get('/logistica/transportistas')).map(TransportistaEstado.fromJson).toList();

  Future<Estadisticas> estadisticas(Periodo periodo) async {
    final (desde, hasta) = periodo.rango();
    final rango = _rango(desde, hasta);
    final respuestas = await Future.wait([
      _api.get('/estadisticas/productos', parametros: {...rango, 'limite': 5}),
      _api.get('/estadisticas/categorias', parametros: rango),
      _api.get('/estadisticas/entregas', parametros: rango),
      _api.get('/estadisticas/stock-bajo'),
    ]);
    return Estadisticas.desde(
      productos: _objeto(respuestas[0]),
      categorias: _objeto(respuestas[1]),
      entregas: _objeto(respuestas[2]),
      stockBajo: respuestas[3] as List,
    );
  }

  /// Todo el catálogo con stock, costo y precio.
  Future<List<ProductoInventario>> inventario() async =>
      _lista(await _api.get('/productos')).map(ProductoInventario.fromJson).toList();

  /// Lotes de un producto, los más recientes primero.
  Future<List<Lote>> lotes(int productoId) async {
    final lista = _lista(await _api.get('/lotes', parametros: {'producto_id': productoId})).map(Lote.fromJson).toList();
    lista.sort((a, b) => (b.fechaRecepcion ?? DateTime(0)).compareTo(a.fechaRecepcion ?? DateTime(0)));
    return lista;
  }

  /// Consumo del mes en curso (lo que el backend da por defecto).
  Future<Consumo> consumo() async => Consumo.fromJson(_objeto(await _api.get('/energia/consumo')));

  Future<List<AlertaEnergia>> alertasEnergia() async =>
      _lista(await _api.get('/energia/alertas')).map(AlertaEnergia.fromJson).toList();
}

final apiGerenciaProvider = Provider<ApiGerencia>((ref) => ApiGerencia(ref.watch(clienteApiProvider)));

/// Panel de hoy.
final panelProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  final hoy = soloFecha(DateTime.now());
  return ref.watch(apiGerenciaProvider).panel(hoy, hoy);
});

final comprasSugeridasProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).compras('sugerida');
});

final comprasConDiferenciasProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).compras('con_diferencias');
});

final comprasAtrasadasProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).comprasAtrasadas();
});

final horasExtraSolicitadasProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).horasExtra(estado: EstadoHoraExtra.solicitada);
});

/// Horas extra aprobadas de esta semana (lunes a domingo).
final horasExtraSemanaProvider = FutureProvider.autoDispose((ref) {
  final lunes = lunesDe(DateTime.now());
  return ref
      .watch(apiGerenciaProvider)
      .horasExtra(estado: EstadoHoraExtra.aprobada, desde: lunes, hasta: lunes.add(const Duration(days: 6)));
});

final horariosProvider = FutureProvider.autoDispose((ref) => ref.watch(apiGerenciaProvider).horarios());

final transportistasProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).transportistas();
});

final estadisticasProvider = FutureProvider.autoDispose.family<Estadisticas, Periodo>((ref, periodo) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).estadisticas(periodo);
});

final consumoProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).consumo();
});

final alertasEnergiaProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).alertasEnergia();
});

final inventarioProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiGerenciaProvider).inventario();
});

final lotesProvider = FutureProvider.autoDispose.family<List<Lote>, int>(
  (ref, productoId) => ref.watch(apiGerenciaProvider).lotes(productoId),
);

/// Recarga lo que se ve en el panel y en aprobaciones.
void recargarGerencia(WidgetRef ref) {
  ref.invalidate(panelProvider);
  ref.invalidate(comprasSugeridasProvider);
  ref.invalidate(comprasConDiferenciasProvider);
  ref.invalidate(comprasAtrasadasProvider);
  ref.invalidate(horasExtraSolicitadasProvider);
  ref.invalidate(transportistasProvider);
  // Aceptar una recepción con diferencias crea un lote: el stock cambia.
  recargarInventario(ref);
}

/// Recarga lo que depende del stock (después de importar el catálogo, recibir mercancía...).
void recargarInventario(WidgetRef ref) {
  ref.invalidate(inventarioProvider);
  ref.invalidate(lotesProvider);
  ref.invalidate(estadisticasProvider);
}
