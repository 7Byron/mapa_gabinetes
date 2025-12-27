import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/spacing.dart';
import '../funcoes/responsive.dart';

enum ButtonResponseType { nunca, raro, sempre }

class Botoes3Respostas extends StatelessWidget {
  final bool pressed;
  final VoidCallback onTap;
  final double width;
  final ButtonResponseType responseType;

  const Botoes3Respostas({
    super.key,
    required this.pressed,
    required this.onTap,
    required this.width,
    required this.responseType,
  });

  // Obter caminho da imagem com base no tipo de resposta
  String get imagePath {
    switch (responseType) {
      case ButtonResponseType.nunca:
        return RotaImagens.nunca;
      case ButtonResponseType.raro:
        return RotaImagens.raro;
      case ButtonResponseType.sempre:
        return RotaImagens.sempre;
    }
  }

  // Obter rótulo com base no tipo de resposta
  String get label {
    switch (responseType) {
      case ButtonResponseType.nunca:
        return "nunca".tr;
      case ButtonResponseType.raro:
        return "vezes".tr;
      case ButtonResponseType.sempre:
        return "sempre".tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            height: MyG.to.margens['margem3']!,
            width: MyG.to.margens['margem3']!,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: pressed
                      ? MyG.to.margem * 2.7
                      : MyG.to.margens['margem3']!,
                  width: pressed
                      ? MyG.to.margem * 2.7
                      : MyG.to.margens['margem3']!,
                  decoration: pressed
                      ? null
                      : BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x80000000),
                              blurRadius: 20.0,
                              offset: Offset(0.0, 5.0),
                            ),
                          ],
                        ),
                  child: Image.asset(imagePath),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: MyG.to.margem, // Espaço reservado para a legenda
          width: width,
          child: Center(
            child: AutoSizeText(
              label,
              maxLines: 2, // Permite 2 linhas para não cortar palavras
              style: TextStyle(
                fontSize: ResponsiveConfig.of(context)
                    .clampFont(ResponsiveConfig.of(context).font(18)),
                fontWeight: FontWeight.bold,
              ),
              minFontSize: 8.0, // Tamanho mínimo para garantir legibilidade
              stepGranularity: 0.5, // Reduz em passos menores
              // Não usa overflow: TextOverflow.ellipsis para não cortar palavras
            ),
          ),
        ),
        SizedBox(height: Spacing.s),
      ],
    );
  }
}
