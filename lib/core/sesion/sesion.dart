import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/cliente_api.dart';
import '../api/modelos.dart';
import 'almacen_seguro.dart';
import 'biometria.dart';
import 'token.dart';

/// Estado de la sesión que ve toda la app.
class EstadoSesion {
  const EstadoSesion({
    this.restaurando = false,
    this.usuario,
    this.token,
    this.expira,
    this.huellaActiva = false,
    this.huellaDisponible = false,
    this.aviso,
  });

  /// true mientras se revisa si quedó una sesión guardada (pantalla de carga).
  final bool restaurando;
  final Usuario? usuario;
  final String? token;

  /// Hasta cuándo dura el token (para operario y transportista, su hora de salida).
  final DateTime? expira;

  /// La persona activó el ingreso con huella en este celular.
  final bool huellaActiva;

  /// El celular tiene biometría registrada.
  final bool huellaDisponible;

  /// Mensaje para mostrar en el login (por ejemplo, «Tu sesión terminó»).
  final String? aviso;

  bool get autenticado => usuario != null && token != null;
}

class SesionNotifier extends Notifier<EstadoSesion> {
  final AlmacenSeguro _almacen = AlmacenSeguro();
  final Biometria _biometria = Biometria();

  /// Cierra la sesión sola cuando llega la hora de salida (vencimiento del token).
  Timer? _cierreAutomatico;

  ClienteApi get _api => ref.read(clienteApiProvider);

  @override
  EstadoSesion build() {
    _api.alNoAutorizado = _sesionVencida;
    ref.onDispose(() => _cierreAutomatico?.cancel());
    Future.microtask(restaurar);
    return const EstadoSesion(restaurando: true);
  }

  void _programarCierre(DateTime? expira) {
    _cierreAutomatico?.cancel();
    _cierreAutomatico = null;
    if (expira == null) return;
    final falta = expira.difference(DateTime.now());
    _cierreAutomatico = Timer(falta.isNegative ? Duration.zero : falta, () {
      _limpiar(aviso: 'Terminó tu jornada. Si tienes horas extra aprobadas, inicia sesión de nuevo.');
    });
  }

  /// Al abrir la app: si quedó una sesión vigente, entra directo.
  Future<void> restaurar() async {
    final huellaActiva = await _almacen.huellaActiva();
    final huellaDisponible = await _biometria.disponible();

    final guardada = await _almacen.leerSesion();
    if (guardada != null) {
      final (token, _) = guardada;
      final expira = expiracionDelToken(token);
      if (expira != null && expira.isAfter(DateTime.now())) {
        _api.token = token;
        try {
          // El servidor confirma que la sesión sigue vigente y trae el rol actual.
          final actual = await _api.perfil();
          if (actual.rol.esPersonal) {
            state = EstadoSesion(
              usuario: actual,
              token: token,
              expira: expira,
              huellaActiva: huellaActiva,
              huellaDisponible: huellaDisponible,
            );
            if (actual.rol.tieneJornada) _programarCierre(expira);
            return;
          }
        } catch (_) {
          // Sesión cerrada, vencida o sin red: se pide iniciar sesión de nuevo.
        }
        _api.token = null;
      }
      await _almacen.borrarSesion();
    }
    state = EstadoSesion(huellaActiva: huellaActiva, huellaDisponible: huellaDisponible);
  }

  /// Inicia sesión con usuario y contraseña. Lanza [ErrorApi] con el mensaje del
  /// servidor (por ejemplo, si es fuera de horario). [ofrecerHuella] se llama una
  /// sola vez, antes de entrar, para preguntar si se quiere activar la huella.
  Future<void> iniciarSesion(
    String usuario,
    String password, {
    Future<bool> Function()? ofrecerHuella,
  }) async {
    final nombreUsuario = usuario.trim();
    final datos = await _api.iniciarSesion(nombreUsuario, password);
    final token = datos['access_token'] as String;
    final persona = Usuario.fromJson(Map<String, dynamic>.from(datos['usuario'] as Map));
    if (!persona.rol.esPersonal) {
      throw ErrorApi('Esta cuenta no pertenece al personal.');
    }

    var huella = state.huellaActiva;
    if (huella) {
      // Mantiene al día el acceso guardado (por si cambió la contraseña).
      await _almacen.activarHuella(nombreUsuario, password);
    } else if (state.huellaDisponible && ofrecerHuella != null) {
      if (await ofrecerHuella()) {
        final confirmada = await _biometria.autenticar('Confirma tu huella para activar el ingreso rápido');
        if (confirmada) {
          await _almacen.activarHuella(nombreUsuario, password);
          huella = true;
        }
      }
    }

    await _entrar(token, persona, huella);
  }

  /// Entra con la huella usando el acceso guardado en este celular.
  Future<void> entrarConHuella() async {
    final credenciales = await _almacen.credenciales();
    if (credenciales == null) {
      await olvidarHuella();
      throw ErrorApi('No hay una huella activada en este celular.');
    }
    final confirmada = await _biometria.autenticar('Confirma tu identidad para entrar a NovaTech');
    if (!confirmada) throw ErrorApi('No se pudo verificar tu huella.');

    final (usuario, password) = credenciales;
    try {
      await iniciarSesion(usuario, password);
    } on ErrorApi catch (e) {
      if (e.codigo == 401) {
        // La contraseña cambió desde que se activó la huella.
        await olvidarHuella();
        throw ErrorApi('Tu contraseña cambió. Ingresa de nuevo y vuelve a activar la huella.');
      }
      rethrow;
    }
  }

  /// Desactiva el ingreso con huella y borra el acceso guardado.
  Future<void> olvidarHuella() async {
    await _almacen.desactivarHuella();
    state = EstadoSesion(
      huellaActiva: false,
      huellaDisponible: state.huellaDisponible,
      usuario: state.usuario,
      token: state.token,
      expira: state.expira,
    );
  }

  /// Botón «salir»: cierra la jornada en el servidor y borra la sesión del celular.
  Future<void> cerrarSesion() async {
    try {
      if (_api.token != null) await _api.salir();
    } catch (_) {
      // Aunque falle el aviso al servidor, la sesión local se cierra igual.
    }
    await _limpiar();
  }

  void _sesionVencida() {
    // El servidor respondió 401: el token venció (hora de salida) o la jornada se cerró.
    _limpiar(aviso: 'Tu sesión terminó. Inicia sesión de nuevo.');
  }

  Future<void> _entrar(String token, Usuario persona, bool huella) async {
    _api.token = token;
    await _almacen.guardarSesion(token, persona);
    final expira = expiracionDelToken(token);
    state = EstadoSesion(
      usuario: persona,
      token: token,
      expira: expira,
      huellaActiva: huella,
      huellaDisponible: state.huellaDisponible,
    );
    if (persona.rol.tieneJornada) _programarCierre(expira);
  }

  Future<void> _limpiar({String? aviso}) async {
    _cierreAutomatico?.cancel();
    _cierreAutomatico = null;
    _api.token = null;
    await _almacen.borrarSesion();
    state = EstadoSesion(
      huellaActiva: await _almacen.huellaActiva(),
      huellaDisponible: state.huellaDisponible,
      aviso: aviso,
    );
  }
}

final sesionProvider = NotifierProvider<SesionNotifier, EstadoSesion>(SesionNotifier.new);
