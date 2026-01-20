import 'package:flutter/material.dart';
import '../models/estatisticas_alocacao.dart';
import '../utils/app_theme.dart';

class EstatisticasAlocacaoCard extends StatelessWidget {
  final EstatisticasAlocacaoData data;

  const EstatisticasAlocacaoCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        if (isNarrow) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MyAppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: MyAppTheme.shadowCard,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildItem(
                        data.numMedicosAlocados.toString(),
                        'médicos alocados',
                        MyAppTheme.azulEscuro,
                      ),
                    ),
                    _buildDivisor(),
                    Expanded(
                      child: _buildItem(
                        data.numMedicosPorAlocar.toString(),
                        'médicos por alocar',
                        MyAppTheme.laranja,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildItem(
                        data.numGabinetesOcupados.toString(),
                        'gabinetes ocupados',
                        MyAppTheme.verde,
                      ),
                    ),
                    _buildDivisor(),
                    Expanded(
                      child: _buildItem(
                        data.numGabinetesLivres.toString(),
                        'gabinetes livres',
                        MyAppTheme.cinzento,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MyAppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: MyAppTheme.shadowCard,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildItem(
                  data.numMedicosAlocados.toString(),
                  'médicos alocados',
                  MyAppTheme.azulEscuro,
                ),
              ),
              _buildDivisor(),
              Expanded(
                child: _buildItem(
                  data.numMedicosPorAlocar.toString(),
                  'médicos por alocar',
                  MyAppTheme.laranja,
                ),
              ),
              _buildDivisor(),
              Expanded(
                child: _buildItem(
                  data.numGabinetesOcupados.toString(),
                  'gabinetes ocupados',
                  MyAppTheme.verde,
                ),
              ),
              _buildDivisor(),
              Expanded(
                child: _buildItem(
                  data.numGabinetesLivres.toString(),
                  'gabinetes livres',
                  MyAppTheme.cinzento,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItem(String numero, String label, Color cor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          numero,
          style: MyAppTheme.heading2.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MyAppTheme.bodySmall.copyWith(
            fontSize: 11,
            color: MyAppTheme.cinzento,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDivisor() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade300,
    );
  }
}
