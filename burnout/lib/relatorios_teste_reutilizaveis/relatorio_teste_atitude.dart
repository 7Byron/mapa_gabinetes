import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:get/get.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/spacing.dart';
import '../widgets/itens_reutilizaveis.dart';

class GraficoAtitude extends StatelessWidget {
  final int sumPassiva;
  final int sumAgressiva;
  final int sumManipuladora;
  final int sumAssertiva;

  const GraficoAtitude({
    super.key,
    required this.sumPassiva,
    required this.sumAgressiva,
    required this.sumManipuladora,
    required this.sumAssertiva,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(Spacing.s),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _buildGraph(Colors.blue, sumPassiva, "passiva_titulo".tr),
              Reuse.myWidthBox025,
              _buildGraph(Colors.red, sumAgressiva, "agressiva_titulo".tr),
              Reuse.myWidthBox025,
              _buildGraph(
                  Colors.orange, sumManipuladora, "manipuladora_titulo".tr),
              Reuse.myWidthBox025,
              _buildGraph(Colors.green, sumAssertiva, "assertiva_titulo".tr),
            ],
          ),
          SizedBox(
            height: MyG.to.margens['margem3']!,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Opacity(
                    opacity:
                        sumPassiva > 15 ? 1.0 : (sumPassiva.toDouble()) / 15,
                    child: Image.asset(RotaImagens.atitude1)),
                Opacity(
                    opacity: sumAgressiva > 15
                        ? 1.0
                        : (sumAgressiva.toDouble()) / 15,
                    child: Image.asset(RotaImagens.atitude2)),
                Opacity(
                    opacity: sumManipuladora > 15
                        ? 1.0
                        : (sumManipuladora.toDouble()) / 15,
                    child: Image.asset(RotaImagens.atitude3)),
                Opacity(
                    opacity: sumAssertiva > 15
                        ? 1.0
                        : (sumAssertiva.toDouble()) / 15,
                    child: Image.asset(RotaImagens.atitude4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Expanded _buildGraph(Color color, int value, String title) {
    final double height = (value * 180) / 15;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            color: color,
            height: height,
            child: FittedBox(
              child: Text(
                "  ${(value * 100 / 15).toStringAsFixed(1)}%  ",
                style: const TextStyle(
                  color: Colors.black38,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          if (value > 0) SizedBox(height: Spacing.xs),
          if (value > 0) AutoSizeText(title, maxLines: 1),
        ],
      ),
    );
  }
}
