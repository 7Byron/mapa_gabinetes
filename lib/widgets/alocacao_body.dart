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
  final bool mostrarSetaMenuLateral;

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
    this.mostrarSetaMenuLateral = false,
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
            if (mostrarSetaMenuLateral && !isCarregando && !isRefreshing)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.north_west,
                        color: Colors.red.shade700,
                        size: 48,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Menu',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
