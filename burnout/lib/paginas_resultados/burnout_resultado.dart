import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/result_template.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/disclamer.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/result_header.dart';
import '../widgets/help_info_button.dart';
import '../funcoes/theme_tokens.dart';

import '../funcoes/graph_palettes_vertical.dart';
import '../widgets_pagina_testes/percent_color.dart';

// ✅ Para os cards "Sobre..." (expand/collapse) igual ao Depressão
import '../widgets/info_card_template.dart';
import '../widgets/expanded_title.dart';

class ResultadoBournt extends StatefulWidget {
  const ResultadoBournt({super.key});

  @override
  State<ResultadoBournt> createState() => _ResultadoBourntState();
}

class _ResultadoBourntState extends State<ResultadoBournt> {
  late final double totalPoints; // 0..72
  late final double exPoints; // 0..24
  late final double disPoints; // 0..24
  late final double realPoints; // 0..24 (bruto)

  late int resultPercent;

  late String textDescricao; // global
  late String textTitulo; // global
  late AssetImage imgTeste;
  late Color cordoCard;

  static const int _maxPerQuestion = 4;
  static const int _totalQuestions = 18;
  static const int _maxTotalPoints = _maxPerQuestion * _totalQuestions; // 72
  static const int _maxDim = 24;

  // cutoffs total (0..72)
  static const int _lowMaxTotal = 24;
  static const int _modMaxTotal = 48;

  // cutoffs dimensão (0..24)
  static const int _lowMaxDim = 8;
  static const int _modMaxDim = 16;

  double _m(String key, double fallback) {
    final v = MyG.to.margens[key];
    if (v == null) return fallback;
    return v.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _readArgs();
    _setGlobalResults();
  }

  void _readArgs() {
    final dynamic raw = Get.arguments;

    // compatibilidade se ainda vier double antigo
    if (raw is double) {
      totalPoints = raw.clamp(0.0, _maxTotalPoints.toDouble());
      exPoints = 0.0;
      disPoints = 0.0;
      realPoints = 0.0;
      resultPercent = _toPercent(totalPoints);
      return;
    }

    final map = (raw as Map?)?.cast<String, dynamic>() ?? {};

    totalPoints =
        (map["total"] is num ? (map["total"] as num).toDouble() : 0.0)
            .clamp(0.0, _maxTotalPoints.toDouble());

    exPoints =
        (map["ex"] is num ? (map["ex"] as num).toDouble() : 0.0)
            .clamp(0.0, _maxDim.toDouble());

    disPoints =
        (map["dis"] is num ? (map["dis"] as num).toDouble() : 0.0)
            .clamp(0.0, _maxDim.toDouble());

    realPoints =
        (map["real"] is num ? (map["real"] as num).toDouble() : 0.0)
            .clamp(0.0, _maxDim.toDouble());

    resultPercent = (map["percent"] is int)
        ? (map["percent"] as int).clamp(0, 100)
        : _toPercent(totalPoints);
  }

  int _toPercent(double points) {
    final clamped = points.clamp(0.0, _maxTotalPoints.toDouble());
    return ((clamped / _maxTotalPoints) * 100).round();
  }

  void _setGlobalResults() {
    final double points = totalPoints;

    if (points <= _lowMaxTotal) {
      imgTeste = const AssetImage(RotaImagens.bur1);
      textTitulo = "burn_res_low_title".tr;
      textDescricao = "burn_res_low_desc".tr;
      cordoCard = Colors.amber.shade50;
      return;
    }

    if (points <= _modMaxTotal) {
      imgTeste = const AssetImage(RotaImagens.bur2);
      textTitulo = "burn_res_mod_title".tr;
      textDescricao = "burn_res_mod_desc".tr;
      cordoCard = Colors.amber.shade200;
      return;
    }

    imgTeste = const AssetImage(RotaImagens.bur3);
    textTitulo = "burn_res_high_title".tr;
    textDescricao = "burn_res_high_desc".tr;
    cordoCard = Colors.amber.shade400;
  }

  // ---------- DIMENSÕES (título apurado + desc apurada) ----------
  Map<String, String> _exDimResult(double points) {
    if (points <= _lowMaxDim) {
      return {
        "title": "burn_dim_ex_low_title".tr,
        "desc": "burn_dim_ex_low_desc".tr,
      };
    }
    if (points <= _modMaxDim) {
      return {
        "title": "burn_dim_ex_mod_title".tr,
        "desc": "burn_dim_ex_mod_desc".tr,
      };
    }
    return {
      "title": "burn_dim_ex_high_title".tr,
      "desc": "burn_dim_ex_high_desc".tr,
    };
  }

  Map<String, String> _disDimResult(double points) {
    if (points <= _lowMaxDim) {
      return {
        "title": "burn_dim_dis_low_title".tr,
        "desc": "burn_dim_dis_low_desc".tr,
      };
    }
    if (points <= _modMaxDim) {
      return {
        "title": "burn_dim_dis_mod_title".tr,
        "desc": "burn_dim_dis_mod_desc".tr,
      };
    }
    return {
      "title": "burn_dim_dis_high_title".tr,
      "desc": "burn_dim_dis_high_desc".tr,
    };
  }

  // Realização (bruta): quanto mais alto, melhor
  Map<String, String> _realDimResult(double points) {
    if (points >= 17) {
      return {
        "title": "burn_dim_real_low_title".tr, // Boa Realização
        "desc": "burn_dim_real_low_desc".tr,
      };
    }
    if (points >= 9) {
      return {
        "title": "burn_dim_real_mod_title".tr,
        "desc": "burn_dim_real_mod_desc".tr,
      };
    }
    return {
      "title": "burn_dim_real_high_title".tr, // Baixa Realização
      "desc": "burn_dim_real_high_desc".tr,
    };
  }

  // ---------- CORES (PercentColor) ----------
  Color _colorForPercent(double percent, List<PercentColor> palette) {
    final p = percent.clamp(0.0, 100.0);
    final sorted = [...palette]..sort((a, b) => b.limit.compareTo(a.limit));
    for (final pc in sorted) {
      if (p >= pc.limit) return pc.color;
    }
    return sorted.isNotEmpty ? sorted.last.color : Colors.grey;
  }

  Color _barColorForDim({
    required double points,
    required bool inverted,
  }) {
    final frac = (points / _maxDim).clamp(0.0, 1.0);
    final percent = frac * 100.0;
    final effectivePercent = inverted ? (100.0 - percent) : percent;
    return _colorForPercent(effectivePercent, PercentPalettesV.burnout);
  }

  // ---------- UI: CARD DE DIMENSÃO ----------
  Widget _dimensionCard({
    required String title,
    required String desc,
    required double points,
    required bool inverted,
  }) {
    final pad05 = _m('margem05', 12);
    final pad03 = _m('margem03', 8);
    final pad02 = _m('margem02', 6);

    final frac = (points / _maxDim).clamp(0.0, 1.0);
    final int percent = (frac * 100).round();
    final barColor = _barColorForDim(points: points, inverted: inverted);

    return Padding(
      padding: EdgeInsets.only(bottom: pad05),
      child: Container(
        decoration: Reuse.mySombraContainer,
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(pad05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AutoSizeText(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.brown,
                  ),
                ),
                SizedBox(height: pad03),

                // ✅ gráfico mais curto
                FractionallySizedBox(
                  widthFactor: 0.85,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 12,
                      backgroundColor: Colors.black.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ),

                SizedBox(height: pad02),

                // ✅ percentagem
                AutoSizeText(
                  "$percent%",
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.brown,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: pad03),
                AutoSizeText(
                  desc,
                  maxLines: 4,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.brown,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- INFO: "Sobre Burnout" (4 cards expandíveis) ----------
  Widget buildBurnoutInfo() {
    return InfoCardTemplate(
      title: "burn_sobre".tr, // "Sobre Burnout"
      topPadding: _m('margem1', 16),
      children: [
        MyTitleExpanded(
          titulo: "burn_ctx_what_title".tr,
          texto: "burn_ctx_what_desc".tr,
        ),
        MyTitleExpanded(
          titulo: "burn_ctx_causes_title".tr,
          texto: "burn_ctx_causes_desc".tr,
        ),
        MyTitleExpanded(
          titulo: "burn_ctx_prevent_title".tr,
          texto: "burn_ctx_prevent_desc".tr,
        ),
        MyTitleExpanded(
          titulo: "burn_ctx_treat_title".tr,
          texto: "burn_ctx_treat_desc".tr,
        ),
        // ⚠️ Se quiseres também "Quando procurar ajuda?" (é o 5º), descomenta:
        // MyTitleExpanded(
        //   titulo: "burn_ctx_help_title".tr,
        //   texto: "burn_ctx_help_desc".tr,
        // ),
        Reuse.myHeigthBox1,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tBurnout".tr,
      appBarImage: RotaImagens.logoBurnout,
      buildResultCard: (context) => buildResultCard(),

      // ✅ Aqui está a parte "Sobre Burnout" antes dos cartões dos testes
      buildInfoCard: (context) => buildBurnoutInfo(),

      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget buildResultCard() {
    final pad05 = _m('margem05', 12);

    final exR = _exDimResult(exPoints);
    final disR = _disDimResult(disPoints);
    final realR = _realDimResult(realPoints);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        boxShadow: Reuse.mySombraContainer.boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        ),
        color: cordoCard,
        child: Padding(
          padding: EdgeInsets.all(pad05),
          child: Column(
            children: [
              // 1) Header: imagem + percentagem
              ResultHeader(image: imgTeste, percentText: "$resultPercent%"),

              SizedBox(height: _m('margem05', 12)),

              // 2) Global: título + descrição
              AutoSizeText(
                textTitulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: _m('margem085', 18),
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
              ),

              SizedBox(height: _m('margem03', 8)),
              _buildHelpIcon(),
              SizedBox(height: _m('margem03', 8)),

              AutoSizeText(
                textDescricao,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: _m('margem075', 14),
                ),
              ),

              SizedBox(height: _m('margem05', 12)),

              // 3) 3 cards
              _dimensionCard(
                title: exR["title"] ?? "",
                desc: exR["desc"] ?? "",
                points: exPoints,
                inverted: false,
              ),
              _dimensionCard(
                title: disR["title"] ?? "",
                desc: disR["desc"] ?? "",
                points: disPoints,
                inverted: false,
              ),
              _dimensionCard(
                title: realR["title"] ?? "",
                desc: realR["desc"] ?? "",
                points: realPoints,
                inverted: true, // baixa realização = pior
              ),

              disclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpIcon() {
    return HelpInfoButton(
      title: "_tBurnout".tr,
      text: """
≤ 33% (0–24 pts)  ${"burn_res_low_title".tr}

34% - 66% (25–48 pts)  ${"burn_res_mod_title".tr}

≥ 67% (49–72 pts)  ${"burn_res_high_title".tr}
""",
    );
  }
}
