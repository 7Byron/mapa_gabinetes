import 'package:get/get.dart';

import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';

class GridItem {
  final String imageAsset;
  final String title;
  final String tipoTeste;
  bool destaque;

  GridItem({
    required this.imageAsset,
    required this.title,
    required this.tipoTeste,
    required this.destaque,
  });
}

class ListaTeste {
  static String get nomeApp => "_tBurnout".tr;
  static String get iconApp => RotaImagens.logoDepressao;

  static List<GridItem> get gridItems => _initializeGridItems();

  static List<GridItem> _initializeGridItems() {
    final bool allApps = MyG.to.allApps;

    return [
      GridItem(
        imageAsset: RotaImagens.logoDepressao,
        title: "_tDepressao",
        tipoTeste: "dep",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoAnsiedade,
        title: "_tAnsiedade",
        tipoTeste: "ans",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoStress,
        title: "_tStress",
        tipoTeste: "str",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoRaiva,
        title: "_tRaiva",
        tipoTeste: "rai",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoDependencia,
        title: "_tDependencia",
        tipoTeste: "emo",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoAtitude,
        title: "_tAtitude",
        tipoTeste: "ati",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoFelicidade,
        title: "_tFelicidade",
        tipoTeste: "fel",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoPersonalidade,
        title: "_tPersonalidade",
        tipoTeste: "per",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoSorriso,
        title: "_tSorriso",
        tipoTeste: "sor",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoAutoConfianca,
        title: "_tAutoConfianca",
        tipoTeste: "aut",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoRelacionamentos,
        title: "_tRelacionamentos",
        tipoTeste: "rel",
        destaque: allApps,
      ),
      GridItem(
        imageAsset: RotaImagens.logoBurnout,
        title: "_tBurnout",
        tipoTeste: "bur",
        destaque: true,
      ),
    ];
  }
}
