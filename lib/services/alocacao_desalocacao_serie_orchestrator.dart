import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../utils/ui_desalocar_cartao_serie.dart';

class AlocacaoDesalocacaoSerieOrchestrator {
  static Future<bool> executar({
    required String medicoId,
    required DateTime data,
    required String tipo,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required Unidade? unidade,
    required Future<void> Function(List<String> gabineteIds)
        recarregarAlocacoesGabinetes,
    required Future<void> Function() recarregarDesalocados,
    required VoidCallback onStateUpdate,
    required VoidCallback onStart,
    required void Function(double, String) onProgresso,
    required VoidCallback onFinish,
    required void Function(Object error) onErro,
    required BuildContext context,
  }) async {
    onStart();
    try {
      final sucesso = await desalocarCartaoSerie(
        medicoId: medicoId,
        data: data,
        tipo: tipo,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        unidade: unidade,
        setState: onStateUpdate,
        recarregarAlocacoesGabinetes: recarregarAlocacoesGabinetes,
        recarregarDesalocados: recarregarDesalocados,
        onProgresso: onProgresso,
        context: context,
      );

      if (!sucesso) {
        throw Exception('Falha ao desalocar série');
      }
      return true;
    } catch (e) {
      onErro(e);
      return false;
    } finally {
      onFinish();
    }
  }
}
