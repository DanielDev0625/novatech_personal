import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/cache.dart';
import 'modelos_admin.dart';

List<Map<String, dynamic>> _lista(dynamic datos) => [
  for (final item in (datos as List)) Map<String, dynamic>.from(item as Map),
];

/// Lo que hace el administrador contra el backend.
class ApiAdmin {
  ApiAdmin(this._api);

  final ClienteApi _api;

  // ---- Usuarios ----

  Future<List<Usuario>> usuarios() async => _lista(await _api.get('/usuarios')).map(Usuario.fromJson).toList();

  Future<void> crearUsuario({
    required String nombre,
    required String usuario,
    required String password,
    required Rol rol,
  }) => _api.post('/usuarios', datos: {'nombre': nombre, 'usuario': usuario, 'password': password, 'rol': rol.name});

  Future<void> cambiarEstadoUsuario(int id, {required bool activo}) =>
      _api.patch('/usuarios/$id/estado', datos: {'activo': activo});

  // ---- Parámetros ----

  Future<Object?> configuracion() => _api.get('/configuracion');

  Future<void> guardarParametros(Parametros nuevos, Parametros originales) async {
    for (final (ruta, cuerpo) in nuevos.cambiosFrente(originales)) {
      await _api.put(ruta, datos: cuerpo);
    }
  }

  // ---- Zonas y equipos de energía ----

  Future<List<Zona>> zonas() async => _lista(await _api.get('/energia/zonas')).map(Zona.fromJson).toList();

  Future<void> crearZona(String nombre, {double? umbralKwhMensual}) =>
      _api.post('/energia/zonas', datos: {'nombre': nombre, 'umbral_kwh_mensual': ?umbralKwhMensual});

  Future<void> crearEquipo({
    required int zonaId,
    required String nombre,
    required double potenciaKw,
    required String tipo,
  }) => _api.post(
    '/energia/equipos',
    datos: {'zona_id': zonaId, 'nombre': nombre, 'potencia_kw': potenciaKw, 'tipo': tipo},
  );

  Future<void> cambiarEstadoEquipo(int id, {required bool activo}) =>
      _api.patch('/energia/equipos/$id/estado', datos: {'activo': activo});

  // ---- Bitácora ----

  Future<List<EntradaBitacora>> bitacora() async =>
      _lista(await _api.get('/bitacora', parametros: {'limite': 200})).map(EntradaBitacora.fromJson).toList();

  // ---- Catálogo ----

  /// Sube el Excel. Con [confirmar] en false solo devuelve la vista previa.
  Future<Object?> importarCatalogo(List<int> bytes, String nombre, {required bool confirmar}) =>
      _api.subirArchivo('/catalogo/importar', bytes: bytes, nombre: nombre, parametros: {'confirmar': confirmar});
}

final apiAdminProvider = Provider<ApiAdmin>((ref) => ApiAdmin(ref.watch(clienteApiProvider)));

/// Cuentas del personal (los clientes tienen su propia app), ordenadas por rol y nombre.
final usuariosProvider = FutureProvider.autoDispose((ref) async {
  cacheDeSesion(ref);
  final lista = await ref.watch(apiAdminProvider).usuarios();
  return lista.where((u) => u.rol.esPersonal).toList()
    ..sort((a, b) => a.rol == b.rol ? a.nombre.compareTo(b.nombre) : a.rol.index - b.rol.index);
});

final configuracionProvider = FutureProvider.autoDispose((ref) {
  cacheDeSesion(ref);
  return ref.watch(apiAdminProvider).configuracion();
});

final zonasProvider = FutureProvider.autoDispose((ref) => ref.watch(apiAdminProvider).zonas());

final bitacoraProvider = FutureProvider.autoDispose((ref) => ref.watch(apiAdminProvider).bitacora());
