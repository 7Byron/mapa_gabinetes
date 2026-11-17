import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/dados_relatorio_exportacao.dart';

/// Mantém o estado visível e impede iniciar outra exportação em simultâneo.
Future<void> executarComProgressoExportacao(BuildContext context,
    Future<void> Function(ProgressoExportacao) exportar) async {
  final estado =
      ValueNotifier<(double, String)>((0.02, 'A preparar o ficheiro…'));
  Future<void> informar(double valor, String mensagem) async {
    estado.value = (valor.clamp(estado.value.$1, 1.0), mensagem);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  final navigator = Navigator.of(context);
  final rota = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('A exportar…'),
        content: SizedBox(
          width: 320,
          child: ValueListenableBuilder<(double, String)>(
              valueListenable: estado,
              builder: (context, valor, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(valor.$2),
                      const SizedBox(height: 20),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: valor.$1),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        builder: (context, progresso, _) =>
                            LinearProgressIndicator(
                          value: progresso,
                          color: AppColors.acao,
                          backgroundColor: AppColors.cabecalho,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('${(valor.$1 * 100).round()}%'),
                        if (valor.$1 >= 0.94 && valor.$1 < 1) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.acao)),
                        ],
                      ]),
                    ],
                  )),
        ),
      ),
    ),
  );
  unawaited(navigator.push(rota));
  try {
    // O primeiro frame do diálogo ainda está transparente. Esperar pela
    // animação evita bloquear a interface antes de o indicador ficar visível.
    final animacao = rota.animation!;
    if (animacao.status != AnimationStatus.completed) {
      final pronto = Completer<void>();
      void verificar(AnimationStatus estado) {
        if (estado == AnimationStatus.completed && !pronto.isCompleted) {
          pronto.complete();
        }
      }

      animacao.addStatusListener(verificar);
      try {
        await pronto.future;
      } finally {
        animacao.removeStatusListener(verificar);
      }
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    await informar(0.04, 'A preparar o ficheiro…');
    await exportar(informar);
    await informar(1, 'Exportação concluída.');
  } finally {
    if (navigator.mounted && rota.isActive) navigator.removeRoute(rota);
  }
}
