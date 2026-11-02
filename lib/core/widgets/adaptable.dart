import 'package:flutter/material.dart';

/// Desde este ancho la app usa diseño de escritorio (menú lateral, contenido centrado).
const anchoEscritorio = 900.0;

/// Ancho máximo del contenido en pantallas grandes, para que no se estire.
const anchoContenido = 880.0;

bool esEscritorio(BuildContext context) => MediaQuery.sizeOf(context).width >= anchoEscritorio;

/// Centra su contenido con un ancho máximo legible; en el celular no cambia nada.
class ContenidoCentrado extends StatelessWidget {
  const ContenidoCentrado({super.key, required this.child, this.ancho = anchoContenido});

  final Widget child;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: ancho), child: child),
    );
  }
}
