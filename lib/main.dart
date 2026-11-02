import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/rutas/rutas.dart';
import 'core/tema/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NovaTechPersonal()));
}

/// App del personal de NovaTech: la usan el operario, el transportista,
/// el gerente y el administrador. El servidor devuelve el rol al iniciar
/// sesión y la app abre la parte que corresponde.
class NovaTechPersonal extends ConsumerWidget {
  const NovaTechPersonal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NovaTech Personal',
      debugShowCheckedModeBanner: false,
      theme: TemaNovaTech.claro(),
      routerConfig: router,
    );
  }
}
