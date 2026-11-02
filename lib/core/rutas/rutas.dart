import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/pantalla_admin.dart';
import '../../features/gerencia/pantalla_gerencia.dart';
import '../../features/operario/pantalla_operario.dart';
import '../../features/transportista/pantalla_transportista.dart';
import '../sesion/pantalla_login.dart';
import '../sesion/sesion.dart';
import '../widgets/pantalla_cargando.dart';

/// Avisa al enrutador cada vez que cambia la sesión, para que revise a dónde debe ir.
class _RefrescoPorSesion extends ChangeNotifier {
  _RefrescoPorSesion(Ref ref) {
    ref.listen<EstadoSesion>(sesionProvider, (anterior, actual) => notifyListeners());
  }
}

/// Navegación por rol:
///  - sin sesión siempre se va al login;
///  - con sesión se va al inicio del rol, y no se puede entrar a pantallas de otro rol.
/// (El servidor valida el rol en cada petición; esto solo ordena la navegación.)
final routerProvider = Provider<GoRouter>((ref) {
  final refresco = _RefrescoPorSesion(ref);
  ref.onDispose(refresco.dispose);

  return GoRouter(
    initialLocation: '/cargando',
    refreshListenable: refresco,
    redirect: (context, estado) {
      final sesion = ref.read(sesionProvider);
      final ruta = estado.matchedLocation;

      if (sesion.restaurando) return ruta == '/cargando' ? null : '/cargando';
      if (!sesion.autenticado) return ruta == '/login' ? null : '/login';

      final inicio = sesion.usuario!.rol.rutaInicio;
      if (ruta == '/login' || ruta == '/cargando') return inicio;
      if (!ruta.startsWith(inicio)) return inicio;
      return null;
    },
    routes: [
      GoRoute(path: '/cargando', builder: (c, e) => const PantallaCargando()),
      GoRoute(path: '/login', builder: (c, e) => const PantallaLogin()),
      GoRoute(path: '/operario', builder: (c, e) => const PantallaOperario()),
      GoRoute(path: '/transportista', builder: (c, e) => const PantallaTransportista()),
      GoRoute(path: '/gerencia', builder: (c, e) => const PantallaGerencia()),
      GoRoute(path: '/admin', builder: (c, e) => const PantallaAdmin()),
    ],
  );
});
