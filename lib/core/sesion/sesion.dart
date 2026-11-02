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
    // Mientras la persona escribe su clave, el servidor ya se va despertando.
    unawaited(_api.despertar());
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

  /// Las escrituras en el almacén seguro van en orden, para que borrar la sesión
  /// anterior nunca pise la que se acaba de guardar.
  Future<void> _cola = Future.value();

  Future<void> _enCola(Future<void> Function() operacion) =>
      _cola = _cola.then((_) => operacion()).then((_) {}, onError: (_) {});

  /// Al abrir la app: si quedó una sesión vigente, entra de inmediato con ella y
  /// el servidor la confirma en segundo plano (sin hacer esperar a la persona).
  Future<void> restaurar() async {
    final (huellaActiva, huellaDisponible, guardada) =
        await (_almacen.huellaActiva(), _biometria.disponible(), _almacen.leerSesion()).wait;

    if (guardada != null) {
      final (token, usuario) = guardada;
      final expira = expiracionDelToken(token);
      if (expira != null && expira.isAfter(DateTime.now()) && usuario.rol.esPersonal) {
        _api.token = token;
        state = EstadoSesion(
          usuario: usuario,
          token: token,
          expira: expira,
          huellaActiva: huellaActiva,
          huellaDisponible: huellaDisponible,
        );
        if (usuario.rol.tieneJornada) _programarCierre(expira);
        unawaited(_confirmarSesion(token));
        return;
      }
      await _enCola(_almacen.borrarSesion);
    }
    state = EstadoSesion(huellaActiva: huellaActiva, huellaDisponible: huellaDisponible);
  }

  /// Pide el perfil para confirmar que la sesión sigue vigente y traer el rol actual.
  /// Si el servidor responde 401, el cliente HTTP cierra la sesión solo; si no hay red,
  /// se sigue con la sesión guardada.
  Future<void> _confirmarSesion(String token) async {
    try {
      final actual = await _api.perfil();
      if (state.token != token) return; // Se salió o entró otra persona mientras tanto.
      if (!actual.rol.esPersonal) {
        await _limpiar();
        return;
      }
      final anterior = state.usuario;
      if (anterior == null || anterior.rol != actual.rol || anterior.nombre != actual.nombre) {
        state = EstadoSesion(
          usuario: actual,
          token: token,
          expira: state.expira,
          huellaActiva: state.huellaActiva,
          huellaDisponible: state.huellaDisponible,
        );
        unawaited(_enCola(() => _almacen.guardarSesion(token, actual)));
      }
    } catch (_) {
      // Sin red por ahora: la sesión guardada sigue sirviendo.
    }
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

  /// Botón «salir»: la sesión se cierra de inmediato en el celular y el aviso al
  /// servidor (que cierra la jornada de hoy) sale en segundo plano con su propio token.
  Future<void> cerrarSesion() async {
    final token = _api.token;
    if (token != null) {
      // Aunque falle el aviso al servidor, la sesión local se cierra igual.
      unawaited(_api.salir(token).then((_) {}, onError: (_) {}));
    }
    await _limpiar();
  }

  void _sesionVencida() {
    // El servidor respondió 401: el token venció (hora de salida) o la jornada se cerró.
    _limpiar(aviso: 'Tu sesión terminó. Inicia sesión de nuevo.');
  }

  Future<void> _entrar(String token, Usuario persona, bool huella) async {
    _api.token = token;
    final expira = expiracionDelToken(token);
    // Primero se entra; guardar en el almacén seguro sigue en segundo plano.
    state = EstadoSesion(
      usuario: persona,
      token: token,
      expira: expira,
      huellaActiva: huella,
      huellaDisponible: state.huellaDisponible,
    );
    if (persona.rol.tieneJornada) _programarCierre(expira);
    await _enCola(() => _almacen.guardarSesion(token, persona));
  }

  Future<void> _limpiar({String? aviso}) async {
    _cierreAutomatico?.cancel();
    _cierreAutomatico = null;
    _api.token = null;
    // Primero se sale (la huella no cambia al cerrar sesión); borrar sigue en segundo plano.
    state = EstadoSesion(
      huellaActiva: state.huellaActiva,
      huellaDisponible: state.huellaDisponible,
      aviso: aviso,
    );
    await _enCola(_almacen.borrarSesion);
  }
}

final sesionProvider = NotifierProvider<SesionNotifier, EstadoSesion>(SesionNotifier.new);
