import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:math' as math;

import '../funcoes/custom_scaffold.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_drawer.dart';
import '../admob/services/banner_ad_widget.dart';
import '../funcoes/spacing.dart';
import '../funcoes/theme_tokens.dart';

class PaginasTestes extends StatefulWidget {
  const PaginasTestes({super.key});

  @override
  State<PaginasTestes> createState() => _PaginasTestesState();
}

class _PaginasTestesState extends State<PaginasTestes> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyG>(
      id: 'compras',
      builder: (myG) {
        final bool ads = myG.adsPago;
        final bool hasAllTests = myG.allApps;

        return CustomScaffold(
          appBar: AppBar(
            centerTitle: true,
            elevation: 6.0,
            title: AutoSizeText(
              "_listaTestes".tr,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          drawer: const MyDrawer(),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: MyG.to.margens['margem22']!,
                  child: Padding(
                    padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                    child: Column(
                      children: [
                        Reuse.myHeigthBox1,
                        _buildAllTestsGrid(hasAllTests),
                        Reuse.myHeigthBox1,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar:
              ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
        );
      },
    );
  }

  Widget _buildAllTestsGrid(bool hasAllTests) {
    final List<Map<String, dynamic>> allTests = [
      {
        "title": "Depressão",
        "image": RotaImagens.logoDepressao,
        "route": "dep",
        "isActive": true,
        "isMain": true,
      },
      {
        "title": "Ansiedade",
        "image": RotaImagens.logoAnsiedade,
        "route": "ans",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Stress",
        "image": RotaImagens.logoStress,
        "route": "str",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Raiva",
        "image": RotaImagens.logoRaiva,
        "route": "rai",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Dependência",
        "image": RotaImagens.logoDependencia,
        "route": "emo",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Atitude",
        "image": RotaImagens.logoAtitude,
        "route": "ati",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Felicidade",
        "image": RotaImagens.logoFelicidade,
        "route": "fel",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Personalidade",
        "image": RotaImagens.logoPersonalidade,
        "route": "per",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Sorriso",
        "image": RotaImagens.logoSorriso,
        "route": "sor",
        "isActive": hasAllTests,
        "isMain": false,
      },
      {
        "title": "Autoconfiança",
        "image": RotaImagens.logoAutoConfianca,
        "route": "aut",
        "isActive": hasAllTests,
        "isMain": false,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Get.context!.isPhone ? 2 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: allTests.length,
      itemBuilder: (context, index) {
        final test = allTests[index];
        return _buildTestCard(
          title: test["title"],
          image: test["image"],
          isActive: test["isActive"],
          isMain: test["isMain"],
          onTap: test["isActive"]
              ? () {
                  Get.toNamed(RotasPaginas.intro,
                      arguments: ['testPrep', test["route"]]);
                }
              : _goToPay,
        );
      },
    );
  }

  // Card de teste unificado
  Widget _buildTestCard({
    required String title,
    required String image,
    required bool isActive,
    required bool isMain,
    required VoidCallback onTap,
  }) {
    final bool isTablet = Get.context!.isTablet;
    final double baseSize = isTablet ? 140 : 120;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
            gradient: isActive
                ? (isMain ? ThemeTokens.gradMain : ThemeTokens.gradActive)
                : ThemeTokens.gradInactive,
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? Colors.black
                        .withValues(alpha: 0.3) // Mais opaco para efeito 3D
                    : Colors.grey.shade400.withValues(alpha: 0.4),
                blurRadius: isActive ? 12 : 6, // Mais difuso para efeito 3D
                offset: const Offset(
                    0, 6), // Mais deslocado para efeito de elevação
              ),
            ],
          ),
          clipBehavior:
              Clip.antiAlias, // Garante que a sombra siga o borderRadius
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(Spacing.m),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: baseSize * 0.5,
                      height: baseSize * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius:
                            BorderRadius.circular(ThemeTokens.radiusMedium),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(Spacing.s),
                        child: Image.asset(
                          image,
                          fit: BoxFit.contain,
                          cacheWidth: math.max(
                            1,
                            (baseSize *
                                    0.5 *
                                    MediaQuery.of(context).devicePixelRatio)
                                .round(),
                          ),
                        ),
                      ),
                    ),
                    Spacing.vs,
                    Text(
                      title,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        fontSize: isTablet ? 16 : 13,
                        fontWeight: FontWeight.bold,
                        shadows: isActive
                            ? [
                                const Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black26,
                                ),
                              ]
                            : null,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isActive)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius:
                          BorderRadius.circular(ThemeTokens.radiusLarge),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToPay() {
    Get.toNamed(RotasPaginas.pay);
  }
}
