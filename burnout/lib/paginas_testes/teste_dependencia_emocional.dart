import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../funcoes/custom_scaffold.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../opcoes_resposta_testes/escala_3.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets_pagina_testes/grafico_percentagem_horizontal.dart';
import '../widgets_pagina_testes/imagem_teste.dart';
import '../widgets_pagina_testes/valor_percentagem.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../funcoes/responsive.dart';
import '../widgets/test_card_container.dart';
import '../widgets/question_header.dart';
import '../funcoes/graph_palettes.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';

class TesteDependenciaEmocional extends StatefulWidget {
  const TesteDependenciaEmocional({super.key});

  @override
  State<TesteDependenciaEmocional> createState() =>
      _TesteDependenciaEmocionalState();
}

class _TesteDependenciaEmocionalState extends State<TesteDependenciaEmocional> {
  late bool ads;
  late int _teste;
  final String _coracao = "💜";
  double _sumValores = 0;
  int _pedeP = 1;
  double _perct = 0;
  bool _voltarPergunta = false;
  double _valAnteriorInt = 0;
  bool _buttonpressed1 = false;
  bool _buttonpressed2 = false;
  bool _buttonpressed3 = false;
  int _toAdsCount = 0;

  @override
  void initState() {
    super.initState();
    ads = MyG.to.adsPago;
    // ✅ CORRIGIDO: Usa 20 como padrão se não houver argumentos
    _teste = Get.arguments != null ? Get.arguments as int : 20;
  }

  Future<void> _obterDadosT20(double valorBotao) async {
    _valAnteriorInt = valorBotao;
    _sumValores = (_sumValores >= 20) ? 20 : _sumValores + valorBotao;

    await Future.delayed(const Duration(milliseconds: 450));

    // Teste rápido (20 perguntas): SEM anúncios intersticiais intercalares
    // Mantido: loadRewardedAd para o rewarded ad no final (diálogo de resultado)

    // Carrega rewarded ad ANTES de incrementar (quando está na pergunta 17, antes de ir para 18)
    // Carrega em background sem bloquear
    if (_pedeP == 17 && !ads) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }

    switch (_pedeP) {
      case 20:
        if (_sumValores > 20) {
          _sumValores = 20;
        }
        HistoricOperator()
            .gravarHistorico("emo", ((_sumValores * 100) / 20).toInt());
        if (ads) {
          Get.toNamed(RotasPaginas.resultadoTesteDependencia,
              arguments: [_teste, _sumValores]);
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
              Get.toNamed(RotasPaginas.resultadoTesteDependencia,
                  arguments: [_teste, 0.0]);
            },
            () async {
              Get.back();
              // Navega imediatamente para o resultado (em background)
              // Quando o usuário fechar o anúncio, já estará na página de resultado
              Get.toNamed(RotasPaginas.resultadoTesteDependencia,
                  arguments: [_teste, _sumValores]);
              // Inicia o anúncio após navegar (não bloqueia a navegação)
              AdManager.to.showRewardedAd();
            },
          );
        }
        break;
    }

    setState(() {
      _perct = (_sumValores * 100) / 20;
      _pedeP++;
      _voltarPergunta = true;
      _buttonpressed1 = false;
      _buttonpressed2 = false;
      _buttonpressed3 = false;
    });
  }

  Future<void> _obterDadosT90(double valorBotao) async {
    _valAnteriorInt = valorBotao;
    _sumValores = (_sumValores >= 91) ? 91 : _sumValores + valorBotao;

    await Future.delayed(const Duration(milliseconds: 450));

    // Teste completo (91 perguntas): Anúncios nas perguntas 20, 40, 60, 80
    // Avisos 3 perguntas antes: 17, 18, 19 (para 20); 37, 38, 39 (para 40);
    // 57, 58, 59 (para 60); 77, 78, 79 (para 80)
    switch (_pedeP) {
      case 17:
      case 37:
      case 57:
      case 77:
        _toAdsCount = 3;
        break;
      case 18:
      case 38:
      case 58:
      case 78:
        _toAdsCount = 2;
        break;
      case 19:
      case 39:
      case 59:
      case 79:
        _toAdsCount = 1;
        break;
      default:
        _toAdsCount = 0;
    }

    // Carregar anúncio 3 perguntas antes (17, 37, 57, 77)
    // Carrega em background sem bloquear
    if (_pedeP == 17 || _pedeP == 37 || _pedeP == 57 || _pedeP == 77) {
      if (!ads) {
        AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
      }
    }

    // Mostrar anúncio nas perguntas 20, 40, 60, 80
    if (_pedeP == 20 || _pedeP == 40 || _pedeP == 60 || _pedeP == 80) {
      if (!ads) {
        // Verifica se há anúncio disponível antes de tentar mostrar
        if (AdManager.to.hasInterstitialAd) {
          // Ignora cooldown para anúncios programados durante o teste
          AdManager.to.showInterstitialAd(ignoreCooldown: true);
        }
        // Se não está carregado, não bloqueia - simplesmente não mostra
        // (já foi tentado carregar nas perguntas anteriores)
      }
    }

    // Carregar rewarded ad ANTES de incrementar (quando está na pergunta 87, antes de ir para 88)
    // Carrega em background sem bloquear
    if (_pedeP == 87 && !ads) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }

    switch (_pedeP) {
      case 91:
        if (_sumValores > 91) {
          _sumValores = 91;
        }
        HistoricOperator()
            .gravarHistorico("emo", ((_sumValores * 100) / 91).toInt());
        if (ads) {
          Get.offNamed('/dependencia_resultado',
              arguments: [_teste, _sumValores]);
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
              Get.offNamed('/dependencia_resultado',
                  arguments: [_teste, _sumValores]);
            },
            () async {
              Get.back();
              // Navega imediatamente para o resultado (em background)
              // Quando o usuário fechar o anúncio, já estará na página de resultado
              Get.offNamed('/dependencia_resultado',
                  arguments: [_teste, _sumValores]);
              // Inicia o anúncio após navegar (não bloqueia a navegação)
              AdManager.to.showRewardedAd();
            },
          );
        }
        break;
    }

    setState(() {
      _perct = (_sumValores * 100) / 91;
      _pedeP++;
      _voltarPergunta = true;
      _buttonpressed1 = false;
      _buttonpressed2 = false;
      _buttonpressed3 = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800;
    return CustomScaffold(
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: RotaImagens.logoDependencia,
        titulo: "_tDependencia".tr,
      ),
      body: Center(
        child: SizedBox(
          width: MyG.to.margens['margem22']!,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SizedBox(
                  height: isShortScreen ? r.spacingSmall : r.spacingMedium),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(Spacing.s),
                  child: TestCardContainer(
                    innerPadding: EdgeInsets.zero,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final double baseInner = 520;
                      // Nunca encolher o conteúdo; apenas permitir crescer levemente
                      const double minScale = 1.0;
                      final double innerScale =
                          (constraints.maxHeight / baseInner)
                              .clamp(minScale, 1.25);
                      final double topPad =
                          isShortScreen ? Spacing.m : Spacing.l;
                      final double bottomPad = Spacing.l;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                            MyG.to
                                .margens['margem1_5']!, // mantido (específico)
                            topPad,
                            MyG.to
                                .margens['margem1_5']!, // mantido (específico)
                            bottomPad),
                        child: Transform.scale(
                          scale: innerScale,
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              QuestionHeader(
                                current: _pedeP,
                                total: _teste == 20 ? 20 : 91,
                                canGoBack: _voltarPergunta,
                                showAdsIcon: !ads && _toAdsCount != 0,
                                adsCount: _toAdsCount,
                                onBack: _voltarPerguntaFunc,
                              ),
                              // Área da pergunta centralizada entre os dividers
                              Expanded(
                                child: Align(
                                  child: TextoPergunta(
                                    questionText: '$_teste-$_pedeP'.tr,
                                    questionIndex: _pedeP,
                                    numeroLinhas: isShortScreen ? 2 : 3,
                                  ),
                                ),
                              ),

                              if ('$_teste-$_pedeP'.tr.contains(_coracao))
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: MyG.to.margens['margem1']!),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Divider(
                                          height: 8,
                                          thickness: 1,
                                          indent: 20,
                                          endIndent: 20,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: r.spacingSmall * 0.4),
                                        Text(
                                          "notay".tr,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            // Nota ~30% menor
                                            fontSize:
                                                r.clampFont(r.font(12) + 2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              buildProgressIndicator(),
              buildResponseButtons(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  SizedBox buildProgressIndicator() {
    return SizedBox(
      height: MediaQuery.of(context).size.height < 800
          ? MyG.to.margens['margem8']! * 0.8
          : MyG.to.margens['margem8']!,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Spacing.s, 0, Spacing.s, Spacing.s),
        child: Container(
          decoration: Reuse.mySombraContainer,
          child: Card(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Padding(
                padding: EdgeInsets.all(Spacing.s),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 110,
                          child: ImageForValues(
                            percentual: _perct,
                            alturaImagem:
                                MediaQuery.of(context).size.height < 800
                                    ? MyG.to.margens['margem4']!
                                    : null,
                            valueImages: ImageThresholds.dependencia,
                          ),
                        ),
                        SizedBox(width: Spacing.s),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final int units = (c.maxWidth / MyG.to.margem)
                                  .floor()
                                  .clamp(6, 10);
                              final double barWidth = MyG.to.margem * units;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Center(
                                    child: SizedBox(
                                      width: barWidth,
                                      child: GraficoPercentagemHorizontal(
                                        perct: _perct,
                                        tamanhografico: units,
                                        heightOverride: Spacing.l,
                                        percentColors:
                                            PercentPalettes.dependencia,
                                      ),
                                    ),
                                  ),
                                  Reuse.myHeigthBox025,
                                  Center(
                                      child: ValorPercentagem(perct: _perct)),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(width: Spacing.s),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  LayoutBuilder buildResponseButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth / 3;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Botoes3Respostas(
              pressed: _buttonpressed1,
              responseType: ButtonResponseType.nunca,
              onTap: () {
                _teste == 20 ? _obterDadosT20(0) : _obterDadosT90(0);
                setState(() => _buttonpressed1 = !_buttonpressed1);
              },
              width: availableWidth,
            ),
            Botoes3Respostas(
              pressed: _buttonpressed2,
              responseType: ButtonResponseType.raro,
              onTap: () {
                _teste == 20 ? _obterDadosT20(0.25) : _obterDadosT90(0.25);
                setState(() => _buttonpressed2 = !_buttonpressed2);
              },
              width: availableWidth,
            ),
            Botoes3Respostas(
              pressed: _buttonpressed3,
              responseType: ButtonResponseType.sempre,
              onTap: () {
                final double valorBotao = _buttonpressed3 ? 1.0 : 0.0;
                _teste == 20
                    ? _obterDadosT20(valorBotao)
                    : _obterDadosT90(valorBotao);
                setState(() => _buttonpressed3 = !_buttonpressed3);
              },
              width: availableWidth,
            ),
          ],
        );
      },
    );
  }

  void _voltarPerguntaFunc() {
    _sumValores -= _valAnteriorInt;
    setState(() {
      _pedeP--;
      _perct = (_sumValores * 100) / _teste;
      _voltarPergunta = false;
    });
  }
}
