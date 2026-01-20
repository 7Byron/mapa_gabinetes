import 'package:flutter/material.dart';
import '../widgets/progresso_carregamento_dialog.dart';

class ProgressoDialogController {
  final BuildContext context;
  final String mensagem;

  double _progresso = 0.0;
  StateSetter? _setState;
  bool _aberto = false;

  ProgressoDialogController({
    required this.context,
    required this.mensagem,
  });

  void abrir() {
    _aberto = true;
    // ignore: unawaited_futures
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            _setState = setState;
            return ProgressoCarregamentoDialog(
              progresso: _progresso,
              mensagem: mensagem,
            );
          },
        );
      },
    );
  }

  void atualizar(double valor) {
    _progresso = valor;
    if (_aberto) {
      _setState?.call(() {});
    }
  }

  void fechar() {
    if (!_aberto) return;
    _aberto = false;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
