import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sesion/sesion.dart';

/// Guarda los datos de una pantalla un rato después de dejar de mirarla, para que
/// volver a ella (o abrirla después de precargarla) sea inmediato.
///  - Si nadie la mira, se descarta pasado [duracion].
///  - Al cambiar la sesión se descarta siempre: otra persona nunca ve datos de la anterior.
void cacheDeSesion<T>(Ref<T> ref, {Duration duracion = const Duration(minutes: 2)}) {
  ref.watch(sesionProvider.select((s) => s.token));

  KeepAliveLink? enlace;
  Timer? reloj;

  void soltarEn(Duration espera) {
    reloj?.cancel();
    enlace ??= ref.keepAlive();
    reloj = Timer(espera, () {
      enlace?.close();
      enlace = null;
    });
  }

  // Recién creada (p. ej. por la precarga) vive [duracion] aunque nadie la mire todavía.
  soltarEn(duracion);
  ref.onCancel(() => soltarEn(duracion));
  ref.onResume(() => reloj?.cancel());
  ref.onDispose(() => reloj?.cancel());
}

/// Empieza a cargar [proveedor] sin esperar el resultado (los errores se verán al abrir la pantalla).
void precargar<T>(WidgetRef ref, ProviderListenable<Future<T>> proveedor) {
  ref.read(proveedor).ignore();
}
