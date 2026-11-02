import 'package:flutter/material.dart';

/// Colores de la marca NovaTech (tomados del logo y del documento de diseño).
/// Si cambian los códigos oficiales, cámbialos solo aquí.
class ColoresNovaTech {
  ColoresNovaTech._();

  static const marino = Color(0xFF0B1F3A);
  static const rojo = Color(0xFFE4002B);
  static const naranja = Color(0xFFFF7A00);
  static const verde = Color(0xFF0A9B45);
  static const azul = Color(0xFF0B6FD8);
  static const texto = Color(0xFF1B2433);
  static const textoSuave = Color(0xFF5B6576);

  /// Fondo de las pantallas y de las tarjetas.
  static const fondo = Colors.white;
  static const tarjeta = Color(0xFFF4F6F9);
  static const borde = Color(0xFFE1E5EC);

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
      surface: Colors.white,
    );
    final redondeo = BorderRadius.circular(12);

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: ColoresNovaTech.fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoresNovaTech.marino,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: ColoresNovaTech.tarjeta,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: redondeo,
          side: const BorderSide(color: ColoresNovaTech.borde),
        ),
      ),
      listTileTheme: const ListTileThemeData(iconColor: ColoresNovaTech.azul),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: redondeo),
        enabledBorder: OutlineInputBorder(
          borderRadius: redondeo,
          borderSide: const BorderSide(color: ColoresNovaTech.borde),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: redondeo),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: redondeo),
          side: const BorderSide(color: ColoresNovaTech.azul),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: ColoresNovaTech.borde),
        selectedColor: ColoresNovaTech.azul,
        secondarySelectedColor: ColoresNovaTech.azul,
        labelStyle: const TextStyle(color: ColoresNovaTech.texto),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        checkmarkColor: Colors.white,
        // Píldoras limpias, como en el diseño: el color ya indica cuál está elegida.
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ColoresNovaTech.azul.withValues(alpha: 0.12),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontSize: 12,
            fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: estados.contains(WidgetState.selected) ? ColoresNovaTech.azul : ColoresNovaTech.textoSuave,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected) ? ColoresNovaTech.azul : ColoresNovaTech.textoSuave,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: ColoresNovaTech.azul,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: ColoresNovaTech.borde),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(color: ColoresNovaTech.borde, space: 1),
    );
  }
}
