import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../admob/ad_manager.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../admob/services/banner_ad_widget.dart';
import '../funcoes/custom_scaffold.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../opcoes_resposta_testes/escala_5.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets/test_card_container.dart';
import '../widgets/question_header.dart';

class PaginaTestePersonalidade extends StatefulWidget {
  const PaginaTestePersonalidade({super.key});

  @override
  State<PaginaTestePersonalidade> createState() =>
      _PaginaTestePersonalidadeState();
}

class _PaginaTestePersonalidadeState extends State<PaginaTestePersonalidade> {
  final bool ads = MyG.to.adsPago;
  // ✅ CORRIGIDO: Usa string padrão se não houver argumentos
  final String _escolha =
      Get.arguments != null ? Get.arguments as String : "geral";
  int _pedeP = 1;
  int _resposta = 0;
  bool _voltarPergunta = false;
  final double altura = (Get.height * 0.055).roundToDouble();
  double _sumAberto = 0;
  double _sumConsciencioso = 0;
  double _sumExtroversao = 0;
  double _sumNeuroticismo = 0;
  double _sumAmabilidade = 0;
  double _barra100 = 0;
  double _abertoAnt = 0;
  double _conscienciosoAnt = 0;
  double _extroversaoAnt = 0;
  double _neuroticismoAnt = 0;
  double _amabilidadeAnt = 0;

  int _toAdsCount = 0;
  final box = GetStorage();

  Future<void> _obterDados() async {
    // Carregar rewarded ad ANTES de incrementar (quando está na pergunta 40, antes de ir para 41)
    // Carrega em background sem bloquear
    if (!ads && _pedeP == 40) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }

    // Carregar intersticial ANTES de incrementar (quando está na pergunta 12, 29, antes de ir para 13, 30)
    // Carrega em background sem bloquear
    if (!ads && (_pedeP == 12 || _pedeP == 29)) {
      AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
    }

    _pedeP++;

    if (!ads) {
      // Carregar também 3 perguntas antes (13, 30) como backup (já carregamos na 12, 29)
      if (_pedeP == 13 || _pedeP == 30) {
        if (!AdManager.to.hasInterstitialAd) {
          AdManager.to
              .loadInterstitialAd(); // Sem await - carrega em background
        }
      }
      // Mostrar anúncios nas perguntas 16 e 33 (antes de incrementar para 17, 34)
      else if (_pedeP == 16 || _pedeP == 33) {
        // Verifica se há anúncio disponível antes de tentar mostrar
        if (AdManager.to.hasInterstitialAd) {
          // Ignora cooldown para anúncios programados durante o teste
          AdManager.to.showInterstitialAd(ignoreCooldown: true);
        }
        // Se não está carregado, não bloqueia - simplesmente não mostra
        // (já foi tentado carregar nas perguntas anteriores)
      }
    }

    // Avisos 3 perguntas antes dos anúncios nas perguntas 17 e 34
    // Pergunta 17: avisos nas 14, 15, 16
    // Pergunta 34: avisos nas 31, 32, 33
    if (_pedeP == 14 || _pedeP == 31) {
      _toAdsCount = 3;
    } else if (_pedeP == 15 || _pedeP == 32) {
      _toAdsCount = 2;
    } else if (_pedeP == 16 || _pedeP == 33) {
      _toAdsCount = 1;
    } else {
      _toAdsCount = 0;
    }

    if (_pedeP == 51) {
      _finalizarTeste();
    }
  }

  Future<void> _finalizarTeste() async {
    int calcularPercentual(double valor, double maximo) {
      return (valor * 100 / maximo).round().clamp(0, 100);
    }

    final intExtroversao = calcularPercentual(_sumExtroversao, 20);
    final intAmabilidade = calcularPercentual(_sumAmabilidade, 26);
    final intConsciencioso = calcularPercentual(_sumConsciencioso, 26);
    final intNeuroticismo = calcularPercentual(_sumNeuroticismo, 26);
    final intAberto = calcularPercentual(_sumAberto, 32);

    final dados =
        "a${intExtroversao}b${intAmabilidade}c${intConsciencioso}d${intNeuroticismo}e${intAberto}f";
    HistoricOperator().gravarHistorico("per", dados);

    final resultadoArgs = [
      _escolha,
      intExtroversao,
      intAmabilidade,
      intConsciencioso,
      intNeuroticismo,
      intAberto
    ];

    if (ads) {
      Get.offNamed(RotasPaginas.resultadoTestePersonalidade,
          arguments: resultadoArgs);
    } else {
      // Se o anúncio não estiver carregado, tenta carregar e aguarda um pouco
      if (!AdManager.to.hasRewardedAd) {
        await AdManager.to.loadRewardedAd();
        // Aguarda até 2 segundos para o anúncio carregar
        int attempts = 0;
        while (!AdManager.to.hasRewardedAd && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }

      showVideoResultadoDialog(
        () {
          Get.back();
          Get.offNamed(RotasPaginas.resultadoTestePersonalidade,
              arguments: ["NA", 0, 0, 0, 0, 0]);
        },
        () async {
          Get.back();
          // Navega imediatamente para o resultado (em background)
          // Quando o usuário fechar o anúncio, já estará na página de resultado
          Get.offNamed(RotasPaginas.resultadoTestePersonalidade,
              arguments: resultadoArgs);
          // Inicia o anúncio após navegar (não bloqueia a navegação)
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  void _onBackPressed() {
    _sumAberto = _abertoAnt;
    _sumAmabilidade = _amabilidadeAnt;
    _sumConsciencioso = _conscienciosoAnt;
    _sumExtroversao = _extroversaoAnt;
    _sumNeuroticismo = _neuroticismoAnt;
    setState(() {
      _pedeP--;
      _voltarPergunta = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _barra100 = Get.width - MyG.to.margem * 4;
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoPersonalidade,
        titulo: "_tPersonalidade".tr,
      ),
      drawer: const MyDrawer(),
      body: Center(
        child: SizedBox(
          width: MyG.to.margens['margem22']!,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                    child: TestCardContainer(
                      innerPadding: EdgeInsets.all(MyG.to.margens['margem05']!),
                      child: Column(
                        children: [
                          Reuse.myHeigthBox050,
                          QuestionHeader(
                            current: _pedeP,
                            total: 50,
                            canGoBack: _voltarPergunta,
                            showAdsIcon: !ads && _toAdsCount != 0,
                            adsCount: _toAdsCount,
                            onBack: _onBackPressed,
                          ),
                          Flexible(
                            flex: 3,
                            child: Center(
                              child: TextoPergunta(
                                  questionText: 'pP$_pedeP'.tr,
                                  questionIndex: _pedeP,
                                  numeroLinhas: 3),
                            ),
                          ),
                          Reuse.myDivider,
                          Expanded(
                            flex: 7,
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _barrasRespostas(
                                  context,
                                  BarraDados(
                                    tipo: "5_e".tr,
                                    corBarra: Colors.cyan,
                                    corFundo: Colors.cyan.shade100,
                                    corBorda: Colors.cyan.shade900,
                                    tamanhoBarra:
                                        (_sumExtroversao * _barra100) / 20,
                                    icon: RotaImagens.per3E,
                                  ),
                                ),
                                _barrasRespostas(
                                  context,
                                  BarraDados(
                                    tipo: "5_a".tr,
                                    corBarra: Colors.green,
                                    corFundo: Colors.green.shade100,
                                    corBorda: Colors.green.shade900,
                                    tamanhoBarra:
                                        (_sumAmabilidade * _barra100) / 26,
                                    icon: RotaImagens.per4N,
                                  ),
                                ),
                                _barrasRespostas(
                                  context,
                                  BarraDados(
                                    tipo: "5_c".tr,
                                    corBarra: Colors.yellow,
                                    corFundo: Colors.yellow.shade100,
                                    corBorda: Colors.yellow.shade900,
                                    tamanhoBarra:
                                        (_sumConsciencioso * _barra100) / 26,
                                    icon: RotaImagens.per2C,
                                  ),
                                ),
                                _barrasRespostas(
                                  context,
                                  BarraDados(
                                    tipo: "5_n".tr,
                                    corBarra: Colors.orange,
                                    corFundo: Colors.orange.shade100,
                                    corBorda: Colors.orange.shade900,
                                    tamanhoBarra:
                                        (_sumNeuroticismo * _barra100) / 26,
                                    icon: RotaImagens.per5A,
                                  ),
                                ),
                                _barrasRespostas(
                                  context,
                                  BarraDados(
                                    tipo: "5_o".tr,
                                    corBarra: Colors.brown,
                                    corFundo: Colors.brown.shade100,
                                    corBorda: Colors.brown.shade900,
                                    tamanhoBarra: (_sumAberto * _barra100) / 32,
                                    icon: RotaImagens.per1A,
                                  ),
                                ),
                                Reuse.myHeigthBox1,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Reuse.myHeigthBox050,
                Botoes5Resposta(
                  onSelectedResponse: (int opcao) {
                    _resposta = opcao;
                    setState(() {
                      _calcularDados();
                      _obterDados();
                      _voltarPergunta = true;
                    });
                  },
                ),
                Reuse.myHeigthBox1,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  void _calcularDados() {
    _extroversaoAnt = _sumExtroversao;
    _amabilidadeAnt = _sumAmabilidade;
    _conscienciosoAnt = _sumConsciencioso;
    _neuroticismoAnt = _sumNeuroticismo;
    _abertoAnt = _sumAberto;

    switch (_pedeP) {
      case 1:
      case 11:
      case 21:
      case 31:
      case 41:
        _sumExtroversao += _resposta;
        break;
      case 6:
      case 16:
      case 26:
      case 36:
      case 46:
        _sumExtroversao -= _resposta;
        break;
      case 7:
      case 17:
      case 27:
      case 37:
      case 42:
      case 47:
        _sumAmabilidade += _resposta;
        break;
      case 2:
      case 12:
      case 22:
      case 32:
        _sumAmabilidade -= _resposta;
        break;
      case 3:
      case 13:
      case 23:
      case 33:
      case 43:
      case 48:
        _sumConsciencioso += _resposta;
        break;
      case 8:
      case 18:
      case 28:
      case 38:
        _sumConsciencioso -= _resposta;
        break;
      case 4:
      case 14:
      case 24:
      case 29:
      case 39:
      case 49:
        _sumNeuroticismo += _resposta;
        break;
      case 9:
      case 19:
      case 34:
      case 44:
        _sumNeuroticismo -= _resposta;
        break;
      case 5:
      case 15:
      case 25:
      case 35:
      case 40:
      case 45:
      case 50:
        _sumAberto += _resposta;
        break;
      case 10:
      case 20:
      case 30:
        _sumAberto -= _resposta;
        break;
    }
  }
}

Widget _barrasRespostas(BuildContext context, BarraDados barra) {
  final porcentagem = ((barra.tamanhoBarra * 100) /
          MyG.to.margens['margem22']!.clamp(300.0, double.infinity))
      .clamp(0, 100)
      .toInt();

  final bool isSmallScreen = MediaQuery.of(context).size.height < 800;
  final double horizontalPadding =
      isSmallScreen ? MyG.to.margens['margem1']! : MyG.to.margens['margem2']!;
  final double verticalSpacing = isSmallScreen
      ? MyG.to.margens['margem025']!
      : MyG.to.margens['margem035']!;
  final double barHeight =
      isSmallScreen ? MyG.to.margens['margem1']! : MyG.to.margens['margem1_5']!;

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
    child: Column(
      children: [
        SizedBox(height: verticalSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Stack(
                children: [
                  _buildBarraFundo(barra.corFundo, barHeight),
                  _buildBarraProgresso(barra.tamanhoBarra, barra.corBarra,
                      barra.corBorda, barHeight),
                  _buildTextoEIcone(
                      barra.tipo, porcentagem, barra.icon, isSmallScreen),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildBarraFundo(Color corFundo, double barraAltura) {
  return Container(
    height: barraAltura,
    width: double.infinity,
    decoration: BoxDecoration(
      color: corFundo,
      border: Border.all(color: corFundo),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
    ),
  );
}

Widget _buildBarraProgresso(
    double tamanhoBarra, Color corBarra, Color corBorda, double barraAltura) {
  return Container(
    height: barraAltura,
    width: tamanhoBarra > 3 ? tamanhoBarra : 0,
    decoration: BoxDecoration(
      color: corBarra,
      border: Border.all(color: corBorda),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
    ),
  );
}

Widget _buildTextoEIcone(
    String tipo, int porcentagem, String icon, bool isSmallScreen) {
  final double padV = isSmallScreen
      ? MyG.to.margens['margem01']!
      : MyG.to.margens['margem025']!;
  final double padH = MyG.to.margens['margem025']!;
  return Padding(
    padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        AutoSizeText(
          "$tipo $porcentagem%",
          style: TextStyle(
            color: Colors.black26,
            fontSize: (isSmallScreen
                    ? MyG.to.margens['margem05']!
                    : MyG.to.margens['margem075']!)
                .clamp(8.0, 18.0),
          ),
          maxLines: 1,
        ),
        Opacity(
          opacity: (porcentagem / 100).clamp(0, 1),
          child: SizedBox(
            width: isSmallScreen
                ? MyG.to.margens['margem1']!
                : MyG.to.margens['margem1_5']!,
            child: Image.asset(icon,
                height: isSmallScreen
                    ? MyG.to.margens['margem085']!
                    : MyG.to.margens['margem1']!),
          ),
        ),
      ],
    ),
  );
}

class BarraDados {
  final String tipo;
  final Color corBarra;
  final Color corFundo;
  final Color corBorda;
  final double tamanhoBarra;
  final String icon;

  BarraDados({
    required this.tipo,
    required this.corBarra,
    required this.corFundo,
    required this.corBorda,
    required this.tamanhoBarra,
    required this.icon,
  });
}
