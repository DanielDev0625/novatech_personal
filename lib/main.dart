import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/rutas/rutas.dart';
import 'core/tema/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // En la web, direcciones limpias (/gerencia/panel) en lugar de /#/gerencia/panel.
  usePathUrlStrategy();
  runApp(const ProviderScope(child: NovaTechPersonal()));
}

/// En la web también se arrastran las listas con el mouse (p. ej. las filas de filtros).
class _DesplazamientoConMouse extends MaterialScrollBehavior {
  const _DesplazamientoConMouse();

  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}

/// App del personal de NovaTech: la usan el operario, el transportista,
/// el gerente y el administrador, en el celular o en el navegador. El servidor
/// devuelve el rol al iniciar sesión y la app abre la parte que corresponde.
class NovaTechPersonal extends ConsumerWidget {
  const NovaTechPersonal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NovaTech Personal',
      debugShowCheckedModeBanner: false,
      theme: TemaNovaTech.claro(),
      scrollBehavior: const _DesplazamientoConMouse(),
      routerConfig: router,
    );
  }
}
