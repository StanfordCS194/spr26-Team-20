import 'package:flutter/material.dart';

// Warm, paper-feeling palette per PRD design notes: "evoke handwriting,
// paper, and intimacy rather than tech."
final ThemeData printimateTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF8C6A4F),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFFAF6EF),
);
