import 'package:flutter/material.dart';
import '../widgets_pagina_testes/percent_color.dart';

class PercentPalettes {
  static const List<PercentColor> ansiedade = [
    PercentColor(limit: 11, color: Colors.green),
    PercentColor(limit: 24, color: Colors.yellow),
    PercentColor(limit: 40, color: Colors.orange),
    PercentColor(limit: 0, color: Colors.red),
  ];

  static const List<PercentColor> depressaoT1 = [
    // Ajustado para combinar com as caixas (tons de âmbar)
    PercentColor(limit: 22, color: Color(0xFFFFECB3)), // amber[200]
    PercentColor(limit: 32, color: Color(0xFFFFC107)), // amber[500]
    PercentColor(limit: 46, color: Color(0xFFFFA000)), // amber[700]
    PercentColor(limit: 0, color: Color(0xFFFF6F00)),  // amber[800] (forte)
  ];

  // Paleta específica usada no Teste 2 de Depressão (valores com cores custom)
  static const List<PercentColor> depressaoT2 = [
    PercentColor(limit: 11, color: Colors.green),
    PercentColor(limit: 20, color: Color(0xFF66FF33)),
    PercentColor(limit: 24, color: Color(0xFFFFFF00)),
    PercentColor(limit: 40, color: Color(0xFFFFCC33)),
    PercentColor(limit: 60, color: Color(0xFFFF6600)),
    PercentColor(limit: 0, color: Colors.red),
  ];

  static const List<PercentColor> felicidade = [
    PercentColor(limit: 20, color: Colors.red),
    PercentColor(limit: 40, color: Colors.orange),
    PercentColor(limit: 60, color: Colors.yellow),
    PercentColor(limit: 80, color: Colors.green),
    PercentColor(limit: 0, color: Colors.cyan),
  ];

  static const List<PercentColor> stress = [
    PercentColor(limit: 16, color: Colors.blue),
    PercentColor(limit: 24, color: Colors.green),
    PercentColor(limit: 40, color: Colors.yellow),
    PercentColor(limit: 48, color: Colors.orange),
    PercentColor(limit: 0, color: Colors.red),
  ];

  static const List<PercentColor> raiva = [
    PercentColor(limit: 10, color: Colors.green),
    PercentColor(limit: 30, color: Colors.yellow),
    PercentColor(limit: 73, color: Colors.orange),
    PercentColor(limit: 0, color: Colors.red),
  ];

  // Auto-confiança: baixa -> alta (vermelho -> verde)
  static const List<PercentColor> autoConfianca = [
    PercentColor(limit: 35, color: Colors.red),
    PercentColor(limit: 68, color: Colors.orange),
    PercentColor(limit: 0, color: Colors.green),
  ];

  // Relacionamentos: baixa -> excelente (vermelho -> azul)
  static const List<PercentColor> relacionamento = [
    PercentColor(limit: 33, color: Colors.red),
    PercentColor(limit: 47, color: Colors.orange),
    PercentColor(limit: 66, color: Colors.yellow),
    PercentColor(limit: 85, color: Colors.green),
    PercentColor(limit: 0, color: Colors.blue),
  ];

  // Sorriso: thresholds simples
  static const List<PercentColor> sorriso = [
    PercentColor(limit: 10, color: Colors.green),
    PercentColor(limit: 18, color: Colors.yellow),
    PercentColor(limit: 30, color: Colors.orange),
    PercentColor(limit: 0, color: Colors.red),
  ];

  // Dependência emocional: utilizada no indicador inferior
  static const List<PercentColor> dependencia = [
    PercentColor(limit: 10, color: Colors.green),
    PercentColor(limit: 25, color: Colors.yellow),
    PercentColor(limit: 40, color: Colors.orange),
    PercentColor(limit: 0, color: Colors.red),
  ];
}

