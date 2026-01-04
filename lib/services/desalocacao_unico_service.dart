/// Serviço para desalocação única: de um gabinete de volta para desalocados (apenas um dia)
/// 
/// Este serviço lida com a desalocação de um médico de um gabinete de volta para
/// a caixa dos desalocados em uma data específica (desalocação única, não série).
library;

import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import 'dart:convert';

class DesalocacaoUnicoService {
  /// Desaloca um médico de um gabinete de volta para desalocados em uma data específica
  /// 
  /// [medicoId] - ID do médico a ser desalocado
  /// [data] - Data da desalocação
  /// [selectedDate] - Data selecionada (pode ser diferente de data)
  /// [alocacoes] - Lista de alocações atuais
  /// [disponibilidades] - Lista de disponibilidades atuais
  /// [medicos] - Lista de médicos
  /// [medicosDisponiveis] - Lista de médicos disponíveis
  /// [unidade] - Unidade para buscar séries/exceções
  /// [onAlocacoesChanged] - Callback para quando as alocações mudarem
  /// [context] - Contexto do Flutter para mostrar mensagens
  /// 
  /// Retorna true se a desalocação foi bem-sucedida, false caso contrário
  static Future<bool> desalocar({
    required String medicoId,
    required DateTime data,
    required DateTime selectedDate,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required Unidade? unidade,
    required VoidCallback onAlocacoesChanged,
    required BuildContext context,
  }) async {

    try {
      // Invalidar cache ANTES de desalocar
      final dataNormalizada = DateTime(data.year, data.month, data.day);
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      await AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
        selectedDate: selectedDate,
        medicoId: medicoId,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        onAlocacoesChanged: onAlocacoesChanged,
        unidade: unidade,
      );

      // Invalidar cache APÓS desalocar
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      return true;
    } catch (e, stackTrace) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desalocar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}

