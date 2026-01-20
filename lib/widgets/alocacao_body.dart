import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/carregamento_overlay.dart';
import '../widgets/desalocacao_serie_overlay.dart';

class AlocacaoBody extends StatelessWidget {
  final bool usarLayoutResponsivo;
  final Widget layoutResponsivo;
  final Widget layoutDesktop;
  final bool isCarregando;
  final bool isRefreshing;
  final String mensagemProgresso;
  final double progressoCarregamento;
  final bool isDesalocandoSerie;
  final String mensagemDesalocacao;
  final double progressoDesalocacao;

  const AlocacaoBody({
    super.key,
    required this.usarLayoutResponsivo,
    required this.layoutResponsivo,
    required this.layoutDesktop,
    required this.isCarregando,
    required this.isRefreshing,
    required this.mensagemProgresso,
    required this.progressoCarregamento,
    required this.isDesalocandoSerie,
    required this.mensagemDesalocacao,
    required this.progressoDesalocacao,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MyAppTheme.backgroundGradientStart,
                    MyAppTheme.backgroundGradientEnd,
                  ],
                ),
              ),
              child: usarLayoutResponsivo ? layoutResponsivo : layoutDesktop,
            ),
            if (isCarregando || isRefreshing)
              CarregamentoOverlay(
                isRefreshing: isRefreshing,
                mensagem: mensagemProgresso,
                progresso: progressoCarregamento,
              ),
            if (isDesalocandoSerie)
              DesalocacaoSerieOverlay(
                mensagem: mensagemDesalocacao,
                progresso: progressoDesalocacao,
              ),
          ],
        );
      },
    );
  }
}
