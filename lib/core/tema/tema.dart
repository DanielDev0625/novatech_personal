import 'package:flutter/material.dart';

/// Colores de la marca NovaTech (aproximados a partir del documento de diseño).
/// Si tienes los códigos oficiales del logo, cámbialos solo aquí.
class ColoresNovaTech {
  ColoresNovaTech._();

  static const marino = Color(0xFF0B1F3A);
  static const rojo = Color(0xFFE4002B);
  static const naranja = Color(0xFFFF7A00);
  static const verde = Color(0xFF0A9B45);
  static const azul = Color(0xFF0070D2);
  static const fondo = Color(0xFFF4F6FA);
  static const texto = Color(0xFF1B2433);

  /// Las cuatro franjas del logo, en orden.
  static const franjas = [rojo, naranja, verde, azul];
}

class TemaNovaTech {
  TemaNovaTech._();

  static ThemeData claro() {
    final esquema = ColorScheme.fromSeed(
      seedColor: ColoresNovaTech.azul,
      primary: ColoresNovaTech.azul,
      secondary: ColoresNovaTech.naranja,
      error: ColoresNovaTech.rojo,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: ColoresNovaTech.fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoresNovaTech.marino,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
