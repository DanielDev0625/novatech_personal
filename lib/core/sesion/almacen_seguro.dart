import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/modelos.dart';

/// Guarda lo sensible en el almacén seguro del celular (Android Keystore):
/// el token de sesión y, si la persona activa la huella, su acceso.
class AlmacenSeguro {
  AlmacenSeguro()
      : _almacen = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _almacen;

  static const _kToken = 'token';
  static const _kUsuario = 'usuario_json';
  static const _kHuella = 'huella_activa';
  static const _kCredUsuario = 'cred_usuario';
  static const _kCredPassword = 'cred_password';

  // ---- Sesión ----

  Future<void> guardarSesion(String token, Usuario usuario) async {
    await _almacen.write(key: _kToken, value: token);
    await _almacen.write(key: _kUsuario, value: jsonEncode(usuario.toJson()));
  }

  Future<(String, Usuario)?> leerSesion() async {
    final token = await _almacen.read(key: _kToken);
    final json = await _almacen.read(key: _kUsuario);
    if (token == null || json == null) return null;
    try {
      final usuario = Usuario.fromJson(jsonDecode(json) as Map<String, dynamic>);
      return (token, usuario);
    } catch (_) {
      return null;
    }
  }

  Future<void> borrarSesion() async {
    await _almacen.delete(key: _kToken);
    await _almacen.delete(key: _kUsuario);
  }

  // ---- Ingreso con huella ----

  Future<bool> huellaActiva() async => (await _almacen.read(key: _kHuella)) == '1';

  /// Guarda el acceso para poder entrar luego con la huella. El token vence a la
  /// hora de salida, así que al día siguiente se vuelve a iniciar sesión con estas
  /// credenciales; el servidor revisa de nuevo el horario.
  Future<void> activarHuella(String usuario, String password) async {
    await _almacen.write(key: _kCredUsuario, value: usuario);
    await _almacen.write(key: _kCredPassword, value: password);
    await _almacen.write(key: _kHuella, value: '1');
  }

  Future<(String, String)?> credenciales() async {
    final usuario = await _almacen.read(key: _kCredUsuario);
    final password = await _almacen.read(key: _kCredPassword);
    if (usuario == null || password == null) return null;
    return (usuario, password);
  }

  Future<void> desactivarHuella() async {
    await _almacen.delete(key: _kCredUsuario);
    await _almacen.delete(key: _kCredPassword);
    await _almacen.delete(key: _kHuella);
  }
}
