import 'package:flutter/material.dart';

class PrintimateColors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF1A1A1A);
  static const border = Color(0xFF2E2E2E);
  static const text = Color(0xFFE8E8E8);
  static const textDim = Color(0xFF8A8A8A);
  static const accent = Color(0xFFE8E8E8);
}

const _mono = 'Courier';
const _monoFallback = ['Menlo', 'monospace'];

final ThemeData printimateTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: PrintimateColors.background,
  colorScheme: const ColorScheme.dark(
    surface: PrintimateColors.background,
    primary: PrintimateColors.accent,
    onPrimary: PrintimateColors.background,
    secondary: PrintimateColors.text,
  ),
  fontFamily: _mono,
  fontFamilyFallback: _monoFallback,
  textTheme: const TextTheme(
    displaySmall: TextStyle(fontFamily: _mono, fontFamilyFallback: _monoFallback, color: PrintimateColors.text, fontSize: 24, letterSpacing: 1.2),
    headlineMedium: TextStyle(fontFamily: _mono, fontFamilyFallback: _monoFallback, color: PrintimateColors.text, fontSize: 20, letterSpacing: 1.0),
    titleLarge: TextStyle(fontFamily: _mono, fontFamilyFallback: _monoFallback, color: PrintimateColors.text, fontSize: 18),
    bodyLarge: TextStyle(fontFamily: _mono, fontFamilyFallback: _monoFallback, color: PrintimateColors.text, fontSize: 15, height: 1.4),
    bodyMedium: TextStyle(fontFamily: _mono, fontFamilyFallback: _monoFallback, color: PrintimateColors.textDim, fontSize: 14, height: 1.4),
    labelLarge: TextStyle(fontFamily: _mono, fontFamilyFallback: _monoFallback, color: PrintimateColors.text, fontSize: 14, letterSpacing: 1.2),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: PrintimateColors.surface,
    hintStyle: const TextStyle(color: PrintimateColors.textDim, fontFamily: _mono, fontFamilyFallback: _monoFallback),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: PrintimateColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: PrintimateColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: PrintimateColors.text),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: PrintimateColors.text,
      side: const BorderSide(color: PrintimateColors.border),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      textStyle: const TextStyle(fontFamily: _mono, fontFamilyFallback: _monoFallback, fontSize: 14, letterSpacing: 1.5),
    ),
  ),
);
