import 'package:geolocator/geolocator.dart';

/// Una posición GPS.
class Punto {
  const Punto(this.latitud, this.longitud);

  final double latitud;
  final double longitud;

  Map<String, dynamic> toJson() => {'latitud': latitud, 'longitud': longitud};

  /// Distancia en metros hasta otra coordenada.
  double metrosHasta(double otraLatitud, double otraLongitud) =>
      Geolocator.distanceBetween(latitud, longitud, otraLatitud, otraLongitud);
}

/// Pide permiso de ubicación si hace falta. Devuelve false si no hay GPS o se niega.
Future<bool> permisoUbicacion() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    return permiso == LocationPermission.whileInUse || permiso == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

/// Posición actual, o la última conocida si el GPS tarda. null si no hay permiso o señal.
/// Nunca lanza: la ubicación ayuda al seguimiento, pero no debe frenar una entrega.
Future<Punto?> ubicacionActual() async {
  if (!await permisoUbicacion()) return null;
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return Punto(p.latitude, p.longitude);
  } catch (_) {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : Punto(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
