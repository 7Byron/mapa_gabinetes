import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:math' as math;

import '../admob/ad_manager.dart';
import '../admob/services/native_ads_widget.dart';
import '../a_config_app/lista_testes.dart';
import '../admob/services/banner_ad_widget.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../funcoes/custom_scaffold.dart';
import '../widgets/my_drawer.dart';
import 'card_ansiedade.dart';
import 'card_atitude.dart';
import 'card_autoconfianca.dart';
import 'card_burnout.dart';
import 'card_dep.dart';
import 'card_dependencia.dart';
import 'card_felicidade.dart';
import 'card_personalidade.dart';
import 'card_raiva.dart';
import 'card_relacionamentos.dart';
import 'card_sorriso.dart';
import 'card_stress.dart';
import 'teste_model.dart';
import 'tipo_teste_utils.dart';
import '../widgets/botao_icon.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../funcoes/spacing.dart';

class Historico extends StatefulWidget {
  const Historico({super.key});

  @override
  State<Historico> createState() => _HistoricoState();
}

class _HistoricoState extends State<Historico> {
  final bool ads = MyG.to.adsPago;
  final GetStorage box = GetStorage();
  final List<TesteModel> testes = [];
  TipoTeste? testeEscolhido;

  @override
  void initState() {
    super.initState();
    Future.microtask(_inicializarDados);
  }

  void _inicializarDados() {
    obterDadosTodos();
    if (!ads) {
      AdManager.to.loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    if (!ads) {
      AdManager.to.showInterstitialAd();
    }
    super.dispose();
  }

  Future<void> obterDadosTodos() async {
    testes.clear();
    final Set<String> seen = <String>{};
    for (TipoTeste tipo in TipoTeste.values) {
      int i = 1;
      while (true) {
        final String key = '${tipo.name}$i';
        final String? registro = box.read(key);
        if (registro == null || registro.isEmpty) break;

        final parts = registro.split('|');
        if (parts.length < 2) break;

        final String data = parts[0].trim();
        final String valor = parts[1].trim();
        final String uniqueKey = '${tipo.name}|$data|$valor';
        if (seen.add(uniqueKey)) {
          testes.add(TesteModel(
            tipo: tipo,
            data: data,
            historico: valor,
          ));
        }
        i++;
      }
    }
    setState(() {});
  }

  void selecionarTeste(TipoTeste tipo) {
    setState(() {
      testeEscolhido = tipo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoApp,
        titulo: "v_hist".tr,
      ),
      drawer: const MyDrawer(),
      body: SingleChildScrollView(
        child: testeEscolhido != null
            ? Center(
                child: SizedBox(
                  width: MyG.to.margens['margem22']!,
                  child: Padding(
                    padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                    child: Column(
                      children: [
                        MyBotaoIcon(
                          onPressed: () {
                            setState(() => testeEscolhido = null);
                          },
                          titulo: "v_hist".tr,
                          linhas: 1,
                          myIcon: Icons.badge_outlined,
                        ),
                        _buildTesteCards(),
                      ],
                    ),
                  ),
                ),
              )
            : Center(
                child: SizedBox(
                  width: MyG.to.margens['margem22']!,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final filteredItems = MyG.to.allApps
                          ? ListaTeste.gridItems
                          : ListaTeste.gridItems
                              .where((item) => item.destaque)
                              .toList();
                      return SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(MyG.to.margens['margem035']!),
                          child: GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent:
                                        Get.context!.isPhone ? 125 : 150,
                                    crossAxisSpacing:
                                        MyG.to.margens['margem065']!,
                                    mainAxisSpacing:
                                        MyG.to.margens['margem065']!,
                                    childAspectRatio: 0.75),
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];

                              final tipoTeste =
                                  stringToTipoTeste(item.tipoTeste);

                              final icon = _getIconForTest(tipoTeste);
                              return InkWell(
                                onTap: () {
                                  final hasHistorico = testes
                                      .any((teste) => teste.tipo == tipoTeste);
                                  if (hasHistorico) {
                                    selecionarTeste(tipoTeste);
                                  } else {
                                    Get.toNamed(RotasPaginas.intro, arguments: [
                                      'testPrep',
                                      item.tipoTeste
                                    ]);
                                  }
                                },
                                child: FadeInItem(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withAlpha((0.2 * 255).toInt()),
                                          spreadRadius: 2,
                                          blurRadius: 5,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          MyG.to.margens['margem065']!),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                  maxHeight: MyG
                                                      .to.margens['margem3']!),
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  final int targetWidth =
                                                      math.max(
                                                    1,
                                                    (constraints.maxWidth *
                                                            MediaQuery.of(
                                                                    context)
                                                                .devicePixelRatio)
                                                        .round(),
                                                  );
                                                  return Image.asset(
                                                    item.imageAsset,
                                                    cacheWidth: targetWidth,
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          Reuse.myHeigthBox1_5,
                                          Expanded(
                                            child: Icon(
                                              icon,
                                              size:
                                                  MyG.to.margens['margem1_25']!,
                                              color: Colors.brown,
                                            ),
                                          ),
                                          Reuse.myHeigthBox025
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
      bottomNavigationBar: ads
          ? Reuse.myHeigthBox1_5
          : const BannerAdWidget(
              collapsible: true, // Banner collapsible (recomendação AdMob)
            ),
    );
  }

  IconData _getIconForTest(TipoTeste tipoTeste) =>
      testes.any((teste) => teste.tipo == tipoTeste)
          ? Icons.remove_red_eye
          : Icons.arrow_right;

  Widget _buildTesteCards() {
    final List<TesteModel> testesDoTipo =
        testes.where((t) => t.tipo == testeEscolhido).toList();
    switch (testeEscolhido) {
      case TipoTeste.dep:
      case TipoTeste.dep2:
        return _buildDepressaoCards("_tDepressao".tr);
      case TipoTeste.ans:
        return _buildCards(testesDoTipo, (teste) => CardAnsiedade(teste: teste),
            "_tAnsiedade".tr);
      case TipoTeste.str:
        return _buildCards(
            testesDoTipo, (teste) => CardStress(teste: teste), "_tStress".tr);
      case TipoTeste.rai:
        return _buildCards(
            testesDoTipo, (teste) => CardRaiva(teste: teste), "_tRaiva".tr);
      case TipoTeste.emo:
        return _buildCards(testesDoTipo,
            (teste) => CardDependencia(teste: teste), "_tDependencia".tr);
      case TipoTeste.ati:
        return _buildCards(
            testesDoTipo, (teste) => CardAtitude(teste: teste), "_tAtitude".tr);
      case TipoTeste.fel:
        return _buildCards(testesDoTipo,
            (teste) => CardFelicidade(teste: teste), "_tFelicidade".tr);
      case TipoTeste.per:
        return _buildCards(testesDoTipo,
            (teste) => CardPersonalidade(teste: teste), "_tPersonalidade".tr);
      case TipoTeste.sor:
        return _buildCards(
            testesDoTipo, (teste) => CardSorriso(teste: teste), "_tSorriso".tr);
      case TipoTeste.aut:
        return _buildCards(testesDoTipo,
            (teste) => CardAutoConfianca(teste: teste), "_tAutoConfianca".tr);
      case TipoTeste.rel:
        return _buildCards(
            testesDoTipo,
            (teste) => CardRelacionamentos(teste: teste),
            "_tRelacionamentos".tr);
      case TipoTeste.bur:
        return _buildCards(
          testesDoTipo,
              (teste) => CardBurnout(teste: teste),
          "_tBurnout".tr,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildCards(List<TesteModel> testesDoTipo,
      Widget Function(TesteModel) cardBuilder, String titulo) {
    if (testesDoTipo.isEmpty) return const SizedBox();
    return Column(
      children: [
        if (!MyG.to.adsPago) const NativeAdReuse(),
        _tituloTesteCard(titulo),
        Column(
          children: testesDoTipo.map((teste) => cardBuilder(teste)).toList(),
        ),
        Reuse.myHeigthBox050,
      ],
    );
  }

  Column _tituloTesteCard(String tituloTeste) {
    return Column(
      children: [
        SizedBox(height: Spacing.s),
        AutoSizeText(
          tituloTeste,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.brown
                : Colors.white,
            fontSize: MyG.to.margens['margem085']!,
            fontWeight: FontWeight.bold,
          ),
          maxLines: MyG.to.margem < 30 ? 2 : 1,
          maxFontSize: (MyG.to.margens['margem1_5']!).toInt().toDouble(),
        ),
        Divider(
          height: 8,
          thickness: 1,
          indent: 20,
          endIndent: 20,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.brown
              : Colors.white,
        ),
      ],
    );
  }

  Widget _buildDepressaoCards(String tituloTeste) {
    final List<TesteModel> testesDepressao = testes
        .where((t) => t.tipo == TipoTeste.dep || t.tipo == TipoTeste.dep2)
        .toList();

    return Column(
      children: [
        _tituloTesteCard(tituloTeste),
        Column(
          children: testesDepressao.map((teste) {
            if (teste.tipo == TipoTeste.dep) {
              return CardDepressaoUnificado(
                  teste: teste, tipoDepressao: TipoDepressao.dep);
            } else if (teste.tipo == TipoTeste.dep2) {
              return CardDepressaoUnificado(
                  teste: teste, tipoDepressao: TipoDepressao.dep2);
            }
            return const SizedBox();
          }).toList(),
        ),
      ],
    );
  }
}

class FadeInItem extends StatefulWidget {
  final Widget child;

  const FadeInItem({super.key, required this.child});

  @override
  FadeInItemState createState() => FadeInItemState();
}

class FadeInItemState extends State<FadeInItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacityAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(opacity: _opacityAnimation.value, child: child);
      },
      child: widget.child,
    );
  }
}
