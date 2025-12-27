import 'package:flutter/material.dart';
import '../widgets_pagina_testes/percent_color.dart';

class PercentPalettesV {
  static const List<PercentColor> autoConfianca = [
    PercentColor(limit: 35, color: Colors.red),
    PercentColor(limit: 68, color: Colors.orange),
    PercentColor(limit: 0, color: Colors.green),
  ];

  static const List<PercentColor> burnout = [
    PercentColor(limit: 67, color: Colors.red),    // ≥ 67% → elevado
    PercentColor(limit: 34, color: Colors.orange), // 34–66% → moderado
    PercentColor(limit: 0, color: Colors.green),   // 0–33% → baixo
  ];


  static const List<PercentColor> relacionamento = [
    PercentColor(limit: 33, color: Colors.red),
    PercentColor(limit: 47, color: Colors.orange),
    PercentColor(limit: 66, color: Colors.yellow),
    PercentColor(limit: 85, color: Colors.green),
    PercentColor(limit: 0, color: Colors.blue),
  ];
}

