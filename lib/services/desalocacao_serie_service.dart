/// Serviço para desalocação de série: de um gabinete de volta para desalocados (toda a série)
/// 
/// Este serviço lida com a desalocação de um médico de um gabinete de volta para
/// a caixa dos desalocados em toda a série (não apenas um dia).
library;

import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';

class DesalocacaoSerieService {
  /// Desaloca um médico de um gabinete de volta para desalocados em toda a série
  /// 
  /// [medicoId] - ID do médico a ser desalocado
  /// [dataRef] - Data de referência da desalocação
  /// [tipo] - Tipo da série (Semanal, Quinzenal, Mensal, etc.)
  /// [selectedDate] - Data selecionada (pode ser diferente de dataRef)
  /// [alocacoes] - Lista de alocações atuais
  /// [disponibilidades] - Lista de disponibilidades atuais
  /// [medicos] - Lista de médicos
  /// [medicosDisponiveis] - Lista de médicos disponíveis
  /// [unidade] - Unidade para buscar séries/exceções
  /// [onAlocacoesChanged] - Callback para quando as alocações mudarem
  /// [onProgresso] - Callback para atualizar progresso (progresso, mensagem)
  /// [context] - Contexto do Flutter para mostrar mensagens
  /// 
  /// Retorna true se a desalocação foi bem-sucedida, false caso contrário
  static Future<bool> desalocar({
    required String medicoId,
    required DateTime dataRef,
    required String tipo,
    required DateTime selectedDate,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required Unidade? unidade,
    required VoidCallback onAlocacoesChanged,
    required void Function(double progresso, String mensagem) onProgresso,
    required BuildContext context,
  }) async {

    try {
      // Invalidar cache ANTES de desalocar série
      final dataNormalizada = DateTime(dataRef.year, dataRef.month, dataRef.day);
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(dataRef.year, 1, 1));

      onProgresso(0.2, 'A remover série...');

      await AlocacaoMedicosLogic.desalocarMedicoSerie(
        medicoId: medicoId,
        dataRef: selectedDate,
        tipo: tipo,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        onAlocacoesChanged: () {
          onProgresso(0.6, 'A atualizar dados...');
          onAlocacoesChanged();
        },
        unidade: unidade,
      );

      onProgresso(0.9, 'A concluir...');
      await Future.delayed(const Duration(milliseconds: 300));

      return true;
    } catch (e) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desalocar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}

