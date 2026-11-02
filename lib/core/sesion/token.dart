import 'dart:convert';

/// Lee la fecha de vencimiento («exp») de un token JWT, sin verificar su firma
/// (eso lo hace el servidor). Sirve para saber hasta cuándo dura la sesión.
/// Para operario y transportista, el token vence a la hora de salida de su jornada.
DateTime? expiracionDelToken(String token) {
  try {
    final partes = token.split('.');
    if (partes.length != 3) return null;
    final carga = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    final datos = jsonDecode(carga) as Map<String, dynamic>;
    final exp = datos['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true).toLocal();
    }
  } catch (_) {
    // Un token mal formado simplemente se trata como sin vencimiento conocido.
  }
  return null;
}
