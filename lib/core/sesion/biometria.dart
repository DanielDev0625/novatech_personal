import 'package:local_auth/local_auth.dart';

/// Huella o reconocimiento facial del celular.
class Biometria {
  final LocalAuthentication _auth = LocalAuthentication();

  /// true si el celular tiene biometría y la persona ya registró al menos una.
  Future<bool> disponible() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final registradas = await _auth.getAvailableBiometrics();
      return registradas.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Pide la huella o el rostro. Devuelve false si se cancela o falla.
  Future<bool> autenticar(String motivo) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
