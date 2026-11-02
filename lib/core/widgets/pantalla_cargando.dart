import 'package:flutter/material.dart';

import '../tema/tema.dart';
import 'marca.dart';

/// Se muestra mientras la app revisa si quedó una sesión guardada.
class PantallaCargando extends StatelessWidget {
  const PantallaCargando({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ColoresNovaTech.marino,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoNovaTech.horizontalBlanco(alto: 72),
            SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
