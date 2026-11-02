import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/api_admin.dart';
import '../../features/admin/pantalla_bitacora.dart';
import '../../features/admin/pantalla_catalogo.dart';
import '../../features/admin/pantalla_parametros.dart';
import '../../features/admin/pantalla_usuarios.dart';
import '../../features/admin/pantalla_zonas.dart';
import '../../features/gerencia/api_gerencia.dart';
import '../../features/gerencia/modelos_gerencia.dart';
import '../../features/gerencia/pantalla_aprobaciones.dart';
import '../../features/gerencia/pantalla_energia.dart';
import '../../features/gerencia/pantalla_estadisticas.dart';
import '../../features/gerencia/pantalla_inventario.dart';
import '../../features/gerencia/pantalla_panel.dart';
import '../../features/gerencia/pantalla_programar_horas.dart';
import '../../features/operario/api_operario.dart';
import '../../features/operario/pantalla_alistar.dart';
import '../../features/operario/pantalla_jornada.dart';
import '../../features/operario/pantalla_recepcion.dart';
import '../../features/operario/pantalla_recibir.dart';
import '../../features/operario/pantalla_tareas.dart';
import '../../features/transportista/api_transportista.dart';
import '../../features/transportista/pantalla_entregar.dart';
import '../../features/transportista/pantalla_entregas.dart';
import '../../features/transportista/pantalla_liquidacion.dart';
import '../../features/transportista/pantalla_ruta.dart';
import '../cache.dart';
import '../sesion/pantalla_login.dart';
import '../sesion/sesion.dart';
import '../widgets/pantalla_cargando.dart';
import '../widgets/scaffold_rol.dart';

/// Avisa al enrutador cada vez que cambia la sesión, para que revise a dónde debe ir.
class _RefrescoPorSesion extends ChangeNotifier {
  _RefrescoPorSesion(Ref ref) {
    ref.listen<EstadoSesion>(sesionProvider, (anterior, actual) => notifyListeners());
  }
}

/// Decide a dónde ir según la sesión (navegación por rol):
///  - sin sesión siempre se va al login;
///  - con sesión se va a la primera pestaña del rol, y no se puede entrar a pantallas de otro rol.
/// (El servidor valida el rol en cada petición; esto solo ordena la navegación.)
String? redireccionPorRol(EstadoSesion sesion, String ruta) {
  if (sesion.restaurando) return ruta == '/cargando' ? null : '/cargando';
  if (!sesion.autenticado) return ruta == '/login' ? null : '/login';

  final rol = sesion.usuario!.rol;
  if (ruta == '/login' || ruta == '/cargando' || ruta == rol.prefijo) return rol.rutaInicio;
  if (!ruta.startsWith('${rol.prefijo}/')) return rol.rutaInicio;
  return null;
}

/// Pestañas de un rol: cada una con su propia pila de navegación.
StatefulShellRoute _pestanas(
  List<Pestana> pestanas,
  List<GoRoute> rutas, {
  void Function(WidgetRef)? precargar,
  void Function(WidgetRef)? alCambiarPestana,
}) {
  return StatefulShellRoute.indexedStack(
    builder: (context, estado, shell) =>
        ShellRol(shell: shell, pestanas: pestanas, precargar: precargar, alCambiarPestana: alCambiarPestana),
    branches: [
      for (final ruta in rutas) StatefulShellBranch(routes: [ruta]),
    ],
  );
}

GoRoute _ruta(String path, Widget pantalla) => GoRoute(path: path, builder: (c, e) => pantalla);

int _id(GoRouterState estado) => int.parse(estado.pathParameters['id']!);

final routerProvider = Provider<GoRouter>((ref) {
  final refresco = _RefrescoPorSesion(ref);
  ref.onDispose(refresco.dispose);

  return GoRouter(
    initialLocation: '/cargando',
    refreshListenable: refresco,
    redirect: (context, estado) => redireccionPorRol(ref.read(sesionProvider), estado.matchedLocation),
    routes: [
      _ruta('/cargando', const PantallaCargando()),
      _ruta('/login', const PantallaLogin()),

      // ---- Operario ----
      _pestanas(
        const [
          Pestana(Icons.checklist, Icons.checklist, 'Tareas'),
          Pestana(Icons.inventory_2_outlined, Icons.inventory_2, 'Recepción'),
          Pestana(Icons.event_note_outlined, Icons.event_note, 'Mi jornada'),
        ],
        [
          _ruta('/operario/tareas', const PantallaTareas()),
          _ruta('/operario/recepcion', const PantallaRecepcion()),
          _ruta('/operario/jornada', const PantallaJornada()),
        ],
        precargar: (ref) {
          precargar(ref, comprasPorRecibirProvider.future);
          precargar(ref, jornadaHoyProvider.future);
          precargar(ref, horasExtraProvider.future);
        },
        alCambiarPestana: recargarOperario,
      ),
      GoRoute(
        path: '/operario/alistar/:id',
        builder: (c, e) => PantallaAlistar(pedidoId: _id(e)),
      ),
      GoRoute(
        path: '/operario/recibir/:id',
        builder: (c, e) => PantallaRecibir(compraId: _id(e)),
      ),

      // ---- Transportista ----
      _pestanas(
        const [
          Pestana(Icons.local_shipping_outlined, Icons.local_shipping, 'Entregas'),
          Pestana(Icons.map_outlined, Icons.map, 'Ruta'),
          Pestana(Icons.payments_outlined, Icons.payments, 'Liquidación'),
        ],
        [
          _ruta('/transportista/entregas', const PantallaEntregas()),
          _ruta('/transportista/ruta', const PantallaRuta()),
          _ruta('/transportista/liquidacion', const PantallaLiquidacion()),
        ],
        precargar: (ref) => precargar(ref, liquidacionProvider.future),
        alCambiarPestana: recargarTransportista,
      ),
      GoRoute(
        path: '/transportista/entregar/:id',
        builder: (c, e) => PantallaEntregar(pedidoId: _id(e)),
      ),

      // ---- Gerencia ----
      _pestanas(
        const [
          Pestana(Icons.dashboard_outlined, Icons.dashboard, 'Panel'),
          Pestana(Icons.fact_check_outlined, Icons.fact_check, 'Aprobar'),
          Pestana(Icons.inventory_2_outlined, Icons.inventory_2, 'Inventario'),
          Pestana(Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
          Pestana(Icons.bolt_outlined, Icons.bolt, 'Energía'),
        ],
        [
          _ruta('/gerencia/panel', const PantallaPanel()),
          _ruta('/gerencia/aprobar', const PantallaAprobaciones()),
          _ruta('/gerencia/inventario', const PantallaInventario()),
          _ruta('/gerencia/estadisticas', const PantallaEstadisticas()),
          _ruta('/gerencia/energia', const PantallaEnergia()),
        ],
        precargar: (ref) {
          precargar(ref, inventarioProvider.future);
          precargar(ref, estadisticasProvider(Periodo.semana).future);
          precargar(ref, consumoProvider.future);
          precargar(ref, alertasEnergiaProvider.future);
        },
        alCambiarPestana: (ref) {
          recargarGerencia(ref);
          ref.invalidate(consumoProvider);
          ref.invalidate(alertasEnergiaProvider);
        },
      ),
      _ruta('/gerencia/horas-extra', const PantallaProgramarHoras()),

      // ---- Administración ----
      _pestanas(
        const [
          Pestana(Icons.group_outlined, Icons.group, 'Usuarios'),
          Pestana(Icons.tune_outlined, Icons.tune, 'Parámetros'),
          Pestana(Icons.inventory_2_outlined, Icons.inventory_2, 'Inventario'),
          Pestana(Icons.upload_file_outlined, Icons.upload_file, 'Catálogo'),
          Pestana(Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
        ],
        [
          _ruta('/admin/usuarios', const PantallaUsuarios()),
          _ruta('/admin/parametros', const PantallaParametros()),
          _ruta('/admin/inventario', const PantallaInventario()),
          _ruta('/admin/catalogo', const PantallaCatalogo()),
          _ruta('/admin/estadisticas', const PantallaEstadisticas()),
        ],
        precargar: (ref) {
          precargar(ref, configuracionProvider.future);
          precargar(ref, inventarioProvider.future);
          precargar(ref, estadisticasProvider(Periodo.semana).future);
        },
        // Parámetros no se recarga solo, para no borrar cambios sin guardar.
        alCambiarPestana: (ref) {
          ref.invalidate(usuariosProvider);
          recargarInventario(ref);
        },
      ),
      _ruta('/admin/zonas', const PantallaZonas()),
      _ruta('/admin/bitacora', const PantallaBitacora()),
    ],
  );
});
