import 'package:flutter/material.dart';

import '../tema/tema.dart';

/// Las cuatro franjas de colores de la marca.
class FranjaColores extends StatelessWidget {
  const FranjaColores({super.key, this.ancho = 120, this.alto = 4});

  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto,
      child: Row(
        children: [
          for (final color in ColoresNovaTech.franjas)
            Expanded(child: ColoredBox(color: color, child: SizedBox(height: alto))),
        ],
      ),
    );
  }
}

/// Logo de texto con las franjas. Para usar el logo real, súbelo a assets/img
/// y reemplaza este widget por un Image.asset.
class LogoNovaTech extends StatelessWidget {
  const LogoNovaTech({super.key, this.tamano = 34, this.color = Colors.white});

  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'NOVATECH',
          style: TextStyle(
            fontSize: tamano,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        FranjaColores(ancho: tamano * 4.2),
      ],
    );
  }
}
