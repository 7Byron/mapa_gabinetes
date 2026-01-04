/// Serviço para alocação única: dos desalocados para um gabinete (apenas um dia)
/// 
/// Este serviço lida com a alocação de um médico que está nos desalocados
/// para um gabinete específico em uma data específica (alocação única, não série).
library;

import 'package:flutter/material.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../utils/series_helper.dart';
import '../services/disponibilidade_serie_service.dart';
import 'dart:convert';

class AlocacaoUnicaService {
  /// Aloca um médico dos desalocados para um gabinete em uma data específica
  /// 
  /// [medicoId] - ID do médico a ser alocado
  /// [gabineteId] - ID do gabinete de destino
  /// [data] - Data da alocação
  /// [disponibilidade] - Disponibilidade do médico para a data
  /// [onAlocarMedico] - Callback para alocar o médico (chama a lógica principal)
  /// [context] - Contexto do Flutter para mostrar mensagens
  /// [serieIdExtraido] - ID da série se a disponibilidade é de uma série (opcional)
  /// 
  /// Retorna true se a alocação foi bem-sucedida, false caso contrário
  static Future<bool> alocar({
    required String medicoId,
    required String gabineteId,
    required DateTime data,
    required Disponibilidade disponibilidade,
    required Future<void> Function(
      String medicoId,
      String gabineteId, {
      DateTime? dataEspecifica,
      List<String>? horarios,
    }) onAlocarMedico,
    required BuildContext context,
    Unidade? unidade,
    String? serieIdExtraido,
  }) async {

    try {
      // CORREÇÃO: Se a disponibilidade é de uma série, criar exceção em vez de salvar alocação única
      String? serieIdFinal = serieIdExtraido;
      
      // Se não foi fornecido, tentar extrair do ID da disponibilidade
      if (serieIdFinal == null && disponibilidade.id.startsWith('serie_')) {
        serieIdFinal = SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidade.id);
      }

      if (serieIdFinal != null && serieIdFinal.isNotEmpty) {
        // É uma série: criar exceção

        await DisponibilidadeSerieService.modificarGabineteDataSerie(
          serieId: serieIdFinal,
          medicoId: medicoId,
          data: data,
          novoGabineteId: gabineteId,
          unidade: unidade,
        );

        // Invalidar cache após criar exceção
        AlocacaoMedicosLogic.invalidateCacheForDay(data);
        AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

        return true;
      }

      // Não é uma série: alocar normalmente (salvar no Firestore)
      // Invalidar cache antes de alocar
      AlocacaoMedicosLogic.invalidateCacheForDay(data);
      
      // Alocar o médico usando o callback
      await onAlocarMedico(
        medicoId,
        gabineteId,
        dataEspecifica: data,
        horarios: disponibilidade.horarios,
      );

      // Invalidar cache após alocar
      AlocacaoMedicosLogic.invalidateCacheForDay(data);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

      return true;
    } catch (e, stackTrace) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alocar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}

