/// Serviço para realocação de série: de um gabinete para outro gabinete (toda a série)
/// 
/// Este serviço lida com a realocação de um médico de um gabinete para outro
/// em toda a série (não apenas um dia).
library;

import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/serie_recorrencia.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';

class RealocacaoSerieService {
  /// Realoca um médico de um gabinete para outro em toda a série
  /// 
  /// [medicoId] - ID do médico a ser realocado
  /// [gabineteOrigem] - ID do gabinete de origem
  /// [gabineteDestino] - ID do gabinete de destino
  /// [dataRef] - Data de referência da realocação
  /// [tipoSerie] - Tipo da série (Semanal, Quinzenal, Mensal, etc.)
  /// [alocacoes] - Lista de alocações atuais (para encontrar a alocação)
  /// [unidade] - Unidade para buscar séries/exceções
  /// [onRealocacaoOtimista] - Callback opcional para atualização otimista
  /// [onAtualizarEstado] - Callback para atualizar o estado após realocação
  /// [onProgresso] - Callback para atualizar progresso (progresso, mensagem)
  /// [onRealocacaoConcluida] - Callback opcional para limpar flags após realocação
  /// [context] - Contexto do Flutter para mostrar mensagens
  /// [verificarSeDataCorrespondeSerie] - Função para verificar se uma data corresponde à série
  /// 
  /// Retorna true se a realocação foi bem-sucedida, false caso contrário
  static Future<bool> realocar({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime dataRef,
    required String tipoSerie,
    required List<Alocacao> alocacoes,
    required Unidade? unidade,
    required BuildContext context,
    void Function(String medicoId, String gabineteOrigem, String gabineteDestino, DateTime data)? onRealocacaoOtimista,
    required VoidCallback onAtualizarEstado,
    required void Function(double progresso, String mensagem) onProgresso,
    VoidCallback? onRealocacaoConcluida,
    required bool Function(DateTime data, SerieRecorrencia serie) verificarSeDataCorrespondeSerie,
  }) async {

    try {
      onProgresso(0.0, 'A iniciar realocação de série...');

      final dataRefNormalizada = DateTime(dataRef.year, dataRef.month, dataRef.day);

      // Procurar alocação no destino primeiro (após atualização otimista), depois na origem
      Alocacao? alocacaoAtual;
      
      try {
        alocacaoAtual = alocacoes.firstWhere(
          (a) {
            final aDate = DateTime(a.data.year, a.data.month, a.data.day);
            return a.medicoId == medicoId &&
                a.gabineteId == gabineteDestino &&
                aDate == dataRefNormalizada;
          },
        );
      } catch (e) {
        try {
          alocacaoAtual = alocacoes.firstWhere(
            (a) {
              final aDate = DateTime(a.data.year, a.data.month, a.data.day);
              return a.medicoId == medicoId &&
                  a.gabineteId == gabineteOrigem &&
                  aDate == dataRefNormalizada;
            },
          );
        } catch (e2) {
          alocacaoAtual = Alocacao(
            id: '',
            medicoId: '',
            gabineteId: '',
            data: DateTime(1900, 1, 1),
            horarioInicio: '',
            horarioFim: '',
          );
        }
      }

      // Buscar série do Firestore
      SerieRecorrencia? serieEncontradaDiretamente;
      String? serieId;

      if (alocacaoAtual.id.isEmpty) {
        // Buscar série diretamente do Firestore
        final series = await SerieService.carregarSeries(
          medicoId,
          unidade: unidade,
        );
        
        // Encontrar série ativa que corresponde ao tipo
        for (final s in series) {
          if (s.ativo && s.tipo == tipoSerie) {
            final dataInicioSerie = DateTime(s.dataInicio.year, s.dataInicio.month, s.dataInicio.day);
            final dataFimSerie = s.dataFim != null 
                ? DateTime(s.dataFim!.year, s.dataFim!.month, s.dataFim!.day)
                : DateTime(dataRef.year + 1, 12, 31);
            
            if (dataRefNormalizada.isAfter(dataInicioSerie.subtract(const Duration(days: 1))) &&
                dataRefNormalizada.isBefore(dataFimSerie.add(const Duration(days: 1)))) {
              serieEncontradaDiretamente = s;
              serieId = s.id;
              break;
            }
          }
        }
        
        if (serieEncontradaDiretamente == null || serieEncontradaDiretamente.id.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nenhuma alocação encontrada na data selecionada'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return false;
        }
      } else if (!alocacaoAtual.id.startsWith('serie_')) {
        // Alocação não é de série, mas usuário escolheu "Toda a série"
        // Buscar série do Firestore baseado no tipoSerie
        final series = await SerieService.carregarSeries(
          medicoId,
          unidade: unidade,
        );
        
        for (final s in series) {
          if (s.ativo && s.tipo == tipoSerie) {
            final dataInicioSerie = DateTime(s.dataInicio.year, s.dataInicio.month, s.dataInicio.day);
            final dataFimSerie = s.dataFim != null 
                ? DateTime(s.dataFim!.year, s.dataFim!.month, s.dataFim!.day)
                : DateTime(dataRef.year + 1, 12, 31);
            
            if (dataRefNormalizada.isAfter(dataInicioSerie.subtract(const Duration(days: 1))) &&
                dataRefNormalizada.isBefore(dataFimSerie.add(const Duration(days: 1)))) {
              serieEncontradaDiretamente = s;
              serieId = s.id;
              break;
            }
          }
        }
        
        if (serieEncontradaDiretamente == null || serieEncontradaDiretamente.id.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Série não encontrada para o tipo especificado'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return false;
        }
      } else {
        // Extrair o ID da série do ID da alocação
        final partes = alocacaoAtual.id.split('_');

        if (partes.length >= 4 && partes[0] == 'serie' && partes[1] == 'serie') {
          serieId = 'serie_${partes[2]}';
        } else if (partes.length >= 3 && partes[0] == 'serie') {
          serieId = partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
        }

        if (serieId == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro ao identificar a série'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        // Buscar a série do serviço
        final series = await SerieService.carregarSeries(
          medicoId,
          unidade: unidade,
        );

        serieEncontradaDiretamente = series.firstWhere(
          (s) => s.id == serieId && s.ativo,
          orElse: () => SerieRecorrencia(
            id: '',
            medicoId: '',
            dataInicio: DateTime.now(),
            tipo: '',
            horarios: [],
          ),
        );
      }

      // Verificar se a série foi encontrada
      if (serieEncontradaDiretamente.id.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Série não encontrada'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final serie = serieEncontradaDiretamente;
      final serieIdFinal = serieId ?? serie.id;

      onProgresso(0.1, 'A atualizar série...');

      // Invalidar cache ANTES de atualizar série
      AlocacaoMedicosLogic.invalidateCacheForDay(dataRefNormalizada);
      final dataFim = serie.dataFim ?? DateTime(dataRef.year + 1, 12, 31);
      DateTime dataCache = dataRefNormalizada.add(const Duration(days: 1));
      while (dataCache.isBefore(dataFim.add(const Duration(days: 1)))) {
        AlocacaoMedicosLogic.invalidateCacheForDay(dataCache);
        dataCache = dataCache.add(const Duration(days: 1));
      }

      // Atualizar o gabinete da série

      await DisponibilidadeSerieService.alocarSerie(
        serieId: serieIdFinal,
        medicoId: medicoId,
        gabineteId: gabineteDestino,
        unidade: unidade,
      );

      onProgresso(0.3, 'A criar exceções...');

      // Criar exceções para as datas anteriores à data de referência
      final dataInicioSerie = DateTime(
        serie.dataInicio.year,
        serie.dataInicio.month,
        serie.dataInicio.day,
      );

      if (dataRefNormalizada.isAfter(dataInicioSerie)) {
        DateTime dataAtual = dataInicioSerie;
        int totalDatas = 0;
        int datasProcessadas = 0;

        // Contar quantas datas precisam ser processadas
        while (dataAtual.isBefore(dataRefNormalizada)) {
          if (verificarSeDataCorrespondeSerie(dataAtual, serie)) {
            totalDatas++;
          }
          dataAtual = dataAtual.add(const Duration(days: 1));
        }

        // Processar cada data
        dataAtual = dataInicioSerie;
        while (dataAtual.isBefore(dataRefNormalizada)) {
          if (verificarSeDataCorrespondeSerie(dataAtual, serie)) {
            await DisponibilidadeSerieService.modificarGabineteDataSerie(
              serieId: serieIdFinal,
              medicoId: medicoId,
              data: dataAtual,
              novoGabineteId: gabineteOrigem,
              unidade: unidade,
            );

            datasProcessadas++;
            if (totalDatas > 0) {
              final progressoExcecoes = datasProcessadas / totalDatas;
              onProgresso(0.3 + (0.4 * progressoExcecoes), 'A criar exceções... ($datasProcessadas/$totalDatas)');
            }
          }
          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      onProgresso(0.7, 'A invalidar cache...');

      // Invalidar cache APÓS atualizar série e criar exceções
      AlocacaoMedicosLogic.invalidateCacheForDay(dataRefNormalizada);
      final dataFimSerie = serie.dataFim ?? DateTime(dataRef.year + 1, 12, 31);
      DateTime dataCacheFinal = dataRefNormalizada.add(const Duration(days: 1));
      while (dataCacheFinal.isBefore(dataFimSerie.add(const Duration(days: 1)))) {
        AlocacaoMedicosLogic.invalidateCacheForDay(dataCacheFinal);
        dataCacheFinal = dataCacheFinal.add(const Duration(days: 1));
      }
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(dataRef.year, 1, 1));

      onProgresso(0.8, 'A sincronizar...');
      await Future.delayed(const Duration(milliseconds: 800));
      onProgresso(0.9, 'A sincronizar com servidor...');
      await Future.delayed(const Duration(milliseconds: 800));
      onAtualizarEstado();
      await Future.delayed(const Duration(milliseconds: 300));
      onProgresso(1.0, 'Completo!');
      await Future.delayed(const Duration(milliseconds: 300));

      if (onRealocacaoConcluida != null) {
        onRealocacaoConcluida();
      }

      return true;
    } catch (e) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao realocar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}

