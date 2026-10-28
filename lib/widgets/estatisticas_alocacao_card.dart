import 'package:flutter/material.dart';
import '../models/estatisticas_alocacao.dart';
import '../utils/app_colors.dart';

/// Resumo numa linha; em ecrãs pequenos passa para duas linhas.
class EstatisticasAlocacaoCard extends StatelessWidget {
  final EstatisticasAlocacaoData data;
  const EstatisticasAlocacaoCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final valores = [
      (data.numMedicosAlocados, 'médicos alocados', AppColors.acao),
      (data.numMedicosPorAlocar, 'por alocar', AppColors.textoAtencao),
      (data.numGabinetesOcupados, 'gabinetes ocupados', AppColors.textoOcupado),
      (data.numGabinetesLivres, 'livres', AppColors.acao),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borda),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final escala = MediaQuery.textScalerOf(context).scale(13) / 13;
        final colunas = constraints.maxWidth >= 680 * escala
            ? 4
            : constraints.maxWidth >= 290 * escala
                ? 2
                : 1;
        return Wrap(runSpacing: 8, children: [
          for (final (numero, texto, cor) in valores)
            SizedBox(
                width: constraints.maxWidth / colunas,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: '$numero ',
                        style: TextStyle(
                            color: cor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: texto,
                        style: const TextStyle(
                            color: AppColors.secundario, fontSize: 12)),
                  ])),
                )),
        ]);
      }),
    );
  }
}
