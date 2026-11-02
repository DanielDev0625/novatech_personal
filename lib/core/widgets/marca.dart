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

enum _VarianteLogo { vertical, horizontalBlanco }

/// Logo oficial de NovaTech.
///  - [LogoNovaTech.vertical]: espiral con el nombre debajo en negro, para fondos claros.
///  - [LogoNovaTech.horizontalBlanco]: espiral y nombre en blanco al lado, para el azul marino.
class LogoNovaTech extends StatelessWidget {
  const LogoNovaTech.vertical({super.key, this.alto = 120}) : _variante = _VarianteLogo.vertical;

  const LogoNovaTech.horizontalBlanco({super.key, this.alto = 56}) : _variante = _VarianteLogo.horizontalBlanco;

  final double alto;
  final _VarianteLogo _variante;

  @override
  Widget build(BuildContext context) {
    final archivo = switch (_variante) {
      _VarianteLogo.vertical => 'assets/img/logo_vertical.png',
      _VarianteLogo.horizontalBlanco => 'assets/img/logo_horizontal_blanco.png',
    };
    return Semantics(
      label: 'NovaTech',
      image: true,
      child: Image.asset(archivo, height: alto, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
    );
  }
}

/// Solo la espiral del logo (para encabezados y espacios pequeños).
class SimboloNovaTech extends StatelessWidget {
  const SimboloNovaTech({super.key, this.tamano = 32});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/img/simbolo.png',
      width: tamano,
      height: tamano,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
