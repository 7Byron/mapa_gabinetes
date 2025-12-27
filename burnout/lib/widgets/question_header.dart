import 'package:flutter/material.dart';
import '../widgets_pagina_testes/contagem_pergunta.dart';

class QuestionHeader extends StatelessWidget {
  final int current;
  final int total;
  final bool canGoBack;
  final bool showAdsIcon;
  final int adsCount;
  final VoidCallback onBack;
  final double? fontSizeOverride;
  final double? heightOverride;
  final double? spacingBeforeDivider;
  final bool thinDivider;

  const QuestionHeader({
    super.key,
    required this.current,
    required this.total,
    required this.canGoBack,
    this.showAdsIcon = false,
    this.adsCount = 0,
    required this.onBack,
    this.fontSizeOverride,
    this.heightOverride,
    this.spacingBeforeDivider,
    this.thinDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinhaContadorPergunta(
          currentQuestion: current,
          totalQuestions: total,
          canGoBack: canGoBack,
          showAdsIcon: showAdsIcon,
          adsCount: adsCount,
          onBackPressed: onBack,
          fontSizeOverride: fontSizeOverride,
          heightOverride: heightOverride,
        ),
        if (spacingBeforeDivider != null)
          SizedBox(height: spacingBeforeDivider),
        Padding(
          // aumenta o padding lateral (6 px adicionais -> total 12 px)
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Divider(
            height: thinDivider ? 4 : 8,
            thickness: thinDivider ? 1 : 1,
            // reduz intensidade para ~50%
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
