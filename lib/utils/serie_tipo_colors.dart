import 'package:flutter/material.dart';

/// Paleta visual compartilhada pelos tipos de marcação.
abstract final class SerieTipoColors {
  static const Color unica = Color(0xFF1565C0);
  static const Color semanal = Color(0xFF2E7D32);
  static const Color quinzenal = Color(0xFFEF6C00);
  static const Color mensal = Color(0xFF7B1FA2);
  static const Color consecutivo = Color(0xFFC62828);

  static Color para(String tipo) {
    if (tipo.startsWith('Consecutivo')) return consecutivo;

    return switch (tipo) {
      'Semanal' => semanal,
      'Quinzenal' => quinzenal,
      'Mensal' => mensal,
      _ => unica,
    };
  }
}
