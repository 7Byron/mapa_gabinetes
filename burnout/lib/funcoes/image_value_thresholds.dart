import '../widgets_pagina_testes/imagem_teste.dart';
import '../funcoes/rota_imagens.dart';

class ImageThresholds {
  static final List<ValueImage> depressaoT1 = [
    ValueImage(limit: 22, imagePath: RotaImagens.dep1),
    ValueImage(limit: 32, imagePath: RotaImagens.dep2),
    ValueImage(limit: 46, imagePath: RotaImagens.logoDepressao),
    ValueImage(limit: 0, imagePath: RotaImagens.dep4),
  ];

  static final List<ValueImage> depressaoT2 = [
    ValueImage(limit: 11, imagePath: RotaImagens.dep1),
    ValueImage(limit: 20, imagePath: RotaImagens.dep2),
    ValueImage(limit: 24, imagePath: RotaImagens.dep2),
    ValueImage(limit: 39, imagePath: RotaImagens.logoDepressao),
    ValueImage(limit: 0, imagePath: RotaImagens.dep4),
  ];

  static final List<ValueImage> felicidade = [
    ValueImage(limit: 20, imagePath: RotaImagens.feliz1),
    ValueImage(limit: 40, imagePath: RotaImagens.feliz2),
    ValueImage(limit: 60, imagePath: RotaImagens.feliz3),
    ValueImage(limit: 80, imagePath: RotaImagens.feliz4),
    ValueImage(limit: 0, imagePath: RotaImagens.feliz5),
  ];

  static final List<ValueImage> sorriso = [
    ValueImage(limit: 53, imagePath: RotaImagens.sorriso1),
    ValueImage(limit: 77, imagePath: RotaImagens.sorriso2),
    ValueImage(limit: 0, imagePath: RotaImagens.logoSorriso),
  ];

  static final List<ValueImage> raiva = [
    ValueImage(limit: 10, imagePath: RotaImagens.raiva1),
    ValueImage(limit: 30, imagePath: RotaImagens.raiva2),
    ValueImage(limit: 73, imagePath: RotaImagens.raiva4),
    ValueImage(limit: 0, imagePath: RotaImagens.logoRaiva),
  ];

  static final List<ValueImage> relacionamento = [
    ValueImage(limit: 33, imagePath: RotaImagens.rel1),
    ValueImage(limit: 47, imagePath: RotaImagens.rel2),
    ValueImage(limit: 66, imagePath: RotaImagens.rel3),
    ValueImage(limit: 85, imagePath: RotaImagens.rel4),
    ValueImage(limit: 0, imagePath: RotaImagens.rel5),
  ];

  static final List<ValueImage> autoConfianca = [
    ValueImage(limit: 35, imagePath: RotaImagens.autoconfianca1),
    ValueImage(limit: 68, imagePath: RotaImagens.autoconfianca2),
    ValueImage(limit: 0, imagePath: RotaImagens.autoconfianca3),
  ];

  static final List<ValueImage> dependencia = [
    ValueImage(limit: 10, imagePath: RotaImagens.depEmo1),
    ValueImage(limit: 25, imagePath: RotaImagens.depEmo2),
    ValueImage(limit: 40, imagePath: RotaImagens.depEmo3),
    ValueImage(limit: 0, imagePath: RotaImagens.depEmo4),
  ];

  static final List<ValueImage> stress = [
    ValueImage(limit: 16, imagePath: RotaImagens.stress1),
    ValueImage(limit: 24, imagePath: RotaImagens.stress2),
    ValueImage(limit: 40, imagePath: RotaImagens.stress3),
    ValueImage(limit: 48, imagePath: RotaImagens.logoStress),
    ValueImage(limit: 0, imagePath: RotaImagens.stress5),
  ];

  static final List<ValueImage> burnout = [
    ValueImage(limit: 24, imagePath: RotaImagens.bur1), // Burnout baixo
    ValueImage(limit: 48, imagePath: RotaImagens.bur2), // Burnout moderado
    ValueImage(limit: 72, imagePath: RotaImagens.bur3), // Burnout elevado
  ];
}

