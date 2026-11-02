import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_personal/core/api/modelos.dart';
import 'package:novatech_personal/core/sesion/token.dart';

String _parte(Map<String, dynamic> datos) =>
    base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');

String _tokenConExp(int exp) => '${_parte({'alg': 'HS256'})}.${_parte({'exp': exp})}.firma';

void main() {
  group('Rol', () {
    test('se lee del texto del servidor', () {
      expect(Rol.desde('operario'), Rol.operario);
      expect(Rol.desde('administrador'), Rol.administrador);
      expect(Rol.desde('algo raro'), Rol.usuario);
      expect(Rol.desde(null), Rol.usuario);
    });

    test('cada rol tiene su pantalla de inicio', () {
      expect(Rol.operario.rutaInicio, '/operario');
      expect(Rol.transportista.rutaInicio, '/transportista');
      expect(Rol.gerente.rutaInicio, '/gerencia');
      expect(Rol.administrador.rutaInicio, '/admin');
    });

    test('solo operario y transportista tienen jornada; el cliente no es personal', () {
      expect(Rol.operario.tieneJornada, isTrue);
      expect(Rol.transportista.tieneJornada, isTrue);
      expect(Rol.gerente.tieneJornada, isFalse);
      expect(Rol.administrador.tieneJornada, isFalse);
      expect(Rol.usuario.esPersonal, isFalse);
      expect(Rol.gerente.esPersonal, isTrue);
    });
  });

  group('Usuario', () {
    test('ida y vuelta a JSON', () {
      const original = Usuario(id: 3, nombre: 'Ana Pérez', usuario: 'ana', rol: Rol.gerente, activo: true);
      final copia = Usuario.fromJson(original.toJson());
      expect(copia.id, 3);
      expect(copia.nombre, 'Ana Pérez');
      expect(copia.rol, Rol.gerente);
    });
  });

  group('expiracionDelToken', () {
    test('lee la fecha de vencimiento', () {
      final exp = DateTime.utc(2026, 11, 3, 22, 0).millisecondsSinceEpoch ~/ 1000;
      final fecha = expiracionDelToken(_tokenConExp(exp));
      expect(fecha, isNotNull);
      expect(fecha!.toUtc(), DateTime.utc(2026, 11, 3, 22, 0));
    });

    test('un token mal formado devuelve null', () {
      expect(expiracionDelToken('no-es-un-token'), isNull);
      expect(expiracionDelToken('a.b.c'), isNull);
    });
  });
}
