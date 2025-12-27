
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets_pagina_testes/status_bar_raiva.dart';


class StatusRow extends StatelessWidget {
  final Map<String, int> valores;
  final int grupo;

  const StatusRow({
    super.key,
    required this.valores,
    required this.grupo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatusBar(tipo: "G1tit".tr, tamanhoBarra: valores["valG1"]!, max: 16, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "G2tit".tr, tamanhoBarra: valores["valG2"]!, max: 32, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "G3tit".tr, tamanhoBarra: valores["valG3"]!, max: 28, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "G4tit".tr, tamanhoBarra: valores["valG4"]!, max: 12, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "G5tit".tr, tamanhoBarra: valores["valG5"]!, max: 84, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "G6tit".tr, tamanhoBarra: valores["valG6"]!, max: 12, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "Inttit".tr, tamanhoBarra: valores["raivaInterna"]!, max: 92, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "Exttit".tr, tamanhoBarra: valores["raivaExterna"]!, max: 44, grupo: grupo),
        const SizedBox(height: 2),
        StatusBar(tipo: "Hostil".tr, tamanhoBarra: valores["prespectivaHostil"]!, max: 36, grupo: grupo),
      ],
    );
  }
}
