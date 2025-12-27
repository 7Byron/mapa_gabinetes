// widgets/card_historico_comum.dart

import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/spacing.dart';
import '../funcoes/responsive.dart';

class CardHistoricoComum extends StatelessWidget {
  final String data;
  final Color cardColor;
  final String imageAsset;
  final int perc;
  final String statusText;

  const CardHistoricoComum({
    super.key,
    required this.data,
    required this.cardColor,
    required this.imageAsset,
    required this.perc,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Spacing.l, vertical: Spacing.xxl),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: Colors.black54,
                ),
                Spacing.hs,
                Text(
                  data,
                  style: const TextStyle(
                    fontSize: 16.0,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Spacing.vs,
            const Divider(color: Colors.black26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image(
                  image: AssetImage(imageAsset),
                  height: 80,
                  width: 100,
                ),
                Text(
                  "$perc %",
                  style: TextStyle(
                    fontSize: ResponsiveConfig.of(context)
                        .clampFont(ResponsiveConfig.of(context).font(18)),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87
                  ),
                ),
                Expanded(
                  child: AutoSizeText(
                    statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                      color: Colors.brown,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
