/// Serviço para realocação de série: de um gabinete para outro gabinete (toda a série)
/// 
/// Este serviço lida com a realocação de um médico de um gabinete para outro
/// em toda a série (não apenas um dia).
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import '../models/alocacao.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
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
    /// [onAtualizarEstado] - Callback async para atualizar o estado após realocação
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
    required Future<void> Function() onAtualizarEstado,
    required void Function(double progresso, String mensagem) onProgresso,
    VoidCallback? onRealocacaoConcluida,
    required bool Function(DateTime data, SerieRecorrencia serie) verificarSeDataCorrespondeSerie,
  }) async {
    // #region agent log
    try {
      final logFile = await File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log').open(mode: FileMode.append);
      await logFile.writeString('${jsonEncode({"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":DateTime.now().millisecondsSinceEpoch,"location":"realocacao_serie_service.dart:realocar:ENTRY","message":"Início realocação série","data":{"medicoId":medicoId,"gabineteOrigem":gabineteOrigem,"gabineteDestino":gabineteDestino,"dataRef":"${dataRef.year}-${dataRef.month}-${dataRef.day}","tipoSerie":tipoSerie},"sessionId":"debug-session","runId":"run1","hypothesisId":"H1,H2,H3"})}\n');
      await logFile.close();
      debugPrint('📝 [DEBUG-LOG] Log escrito: Início realocação série');
    } catch (e) {
      debugPrint('❌ [DEBUG-LOG] Erro ao escrever log: $e');
    }
    // #endregion

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

      // #region agent log
      try {
        final logFile = await File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log').open(mode: FileMode.append);
        await logFile.writeString('${jsonEncode({"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":DateTime.now().millisecondsSinceEpoch,"location":"realocacao_serie_service.dart:realocar:SERIE_ENCONTRADA","message":"Série encontrada","data":{"serieId":serieIdFinal,"gabineteIdAtual":serie.gabineteId,"gabineteOrigem":gabineteOrigem,"gabineteDestino":gabineteDestino,"dataInicio":"${serie.dataInicio.year}-${serie.dataInicio.month}-${serie.dataInicio.day}","dataFim":serie.dataFim!=null?"${serie.dataFim!.year}-${serie.dataFim!.month}-${serie.dataFim!.day}":"null","tipo":serie.tipo},"sessionId":"debug-session","runId":"run1","hypothesisId":"H1,H2"})}\n');
        await logFile.close();
      } catch (e) {}
      // #endregion

      onProgresso(0.1, 'A atualizar série...');

      // CORREÇÃO: Não atualizar toda a série de uma vez
      // Em vez disso, criar exceções para manter o gabinete original nas datas anteriores
      // e atualizar apenas o gabinete da série (que afetará apenas datas futuras sem exceção)
      
      final dataInicioSerie = DateTime(
        serie.dataInicio.year,
        serie.dataInicio.month,
        serie.dataInicio.day,
      );

      // Se há datas anteriores à data de referência, criar exceções APENAS para datas que não têm exceção
      // ou que têm exceção mas o gabineteId já é diferente do gabineteOrigem
      // NÃO criar/atualizar se já existe exceção com gabineteId == null (sem gabinete - deve manter)
      if (dataRefNormalizada.isAfter(dataInicioSerie)) {
        onProgresso(0.15, 'A verificar datas anteriores...');
        
        // Carregar todas as exceções existentes de uma vez (mais eficiente)
        final excecoesExistentes = await SerieService.carregarExcecoes(
          medicoId,
          unidade: unidade,
          dataInicio: dataInicioSerie,
          dataFim: dataRefNormalizada.subtract(const Duration(days: 1)),
          serieId: serieIdFinal,
          forcarServidor: true, // CORREÇÃO: Forçar servidor para garantir dados atualizados
        );
        
        // Criar mapa de exceções por data para busca rápida
        final excecoesPorData = <String, ExcecaoSerie>{};
        for (final excecao in excecoesExistentes) {
          if (excecao.serieId == serieIdFinal && !excecao.cancelada) {
            final dataKey = '${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
            excecoesPorData[dataKey] = excecao;
          }
        }
        
        DateTime dataAtual = dataInicioSerie;
        int totalDatas = 0;
        int datasProcessadas = 0;

        // Contar quantas datas precisam ser processadas (apenas as que não têm exceção ou têm exceção com gabinete diferente)
        while (dataAtual.isBefore(dataRefNormalizada)) {
          if (verificarSeDataCorrespondeSerie(dataAtual, serie)) {
            final dataKey = '${dataAtual.year}-${dataAtual.month}-${dataAtual.day}';
            final excecaoExistente = excecoesPorData[dataKey];
            
            // CORREÇÃO: Só precisa criar/atualizar exceção se:
            // 1. Não há exceção, OU
            // 2. Há exceção mas o gabineteId é diferente do gabineteOrigem E não é null
            // NÃO criar/atualizar se gabineteId é null (exceção de gabinete sem gabinete - deve manter)
            if (excecaoExistente == null) {
              // Não há exceção - precisa criar
              totalDatas++;
            } else if (excecaoExistente.gabineteId != null && excecaoExistente.gabineteId != gabineteOrigem) {
              // Há exceção mas com gabinete diferente - precisa atualizar
              totalDatas++;
            }
            // Se excecaoExistente.gabineteId == null, não criar/atualizar (manter exceção de gabinete sem gabinete)
          }
          dataAtual = dataAtual.add(const Duration(days: 1));
        }

        // Criar exceções apenas para datas que precisam
        if (totalDatas > 0) {
          onProgresso(0.20, 'A criar exceções para datas anteriores... ($totalDatas datas)');
          
          dataAtual = dataInicioSerie;
          while (dataAtual.isBefore(dataRefNormalizada)) {
            if (verificarSeDataCorrespondeSerie(dataAtual, serie)) {
              final dataKey = '${dataAtual.year}-${dataAtual.month}-${dataAtual.day}';
              final excecaoExistente = excecoesPorData[dataKey];
              
              // CORREÇÃO: Só criar/atualizar exceção se necessário
              // NÃO criar/atualizar se já existe exceção com gabineteId == null
              if (excecaoExistente == null) {
                // Não há exceção - criar exceção para manter o gabinete original
                await DisponibilidadeSerieService.modificarGabineteDataSerie(
                  serieId: serieIdFinal,
                  medicoId: medicoId,
                  data: dataAtual,
                  novoGabineteId: gabineteOrigem, // Manter gabinete original nas datas anteriores
                  unidade: unidade,
                );

                datasProcessadas++;
                if (totalDatas > 0) {
                  final progressoExcecoes = datasProcessadas / totalDatas;
                  onProgresso(0.20 + (0.20 * progressoExcecoes), 'A criar exceções... ($datasProcessadas/$totalDatas)');
                }
              } else if (excecaoExistente.gabineteId != null && excecaoExistente.gabineteId != gabineteOrigem) {
                // Há exceção mas com gabinete diferente - atualizar para manter gabinete original
                await DisponibilidadeSerieService.modificarGabineteDataSerie(
                  serieId: serieIdFinal,
                  medicoId: medicoId,
                  data: dataAtual,
                  novoGabineteId: gabineteOrigem, // Manter gabinete original nas datas anteriores
                  unidade: unidade,
                );

                datasProcessadas++;
                if (totalDatas > 0) {
                  final progressoExcecoes = datasProcessadas / totalDatas;
                  onProgresso(0.20 + (0.20 * progressoExcecoes), 'A criar exceções... ($datasProcessadas/$totalDatas)');
                }
              }
              // CORREÇÃO: Se excecaoExistente.gabineteId == null, não fazer nada (manter exceção de gabinete sem gabinete)
            }
            dataAtual = dataAtual.add(const Duration(days: 1));
          }
        }
      }

      // Passo 2: CANCELAR todas as exceções para datas >= dataRef
      // CORREÇÃO CRÍTICA: Não criar/atualizar exceções para datas futuras
      // A série será atualizada com o novo gabineteId, que será aplicado automaticamente para datas sem exceção
      // Exceções devem ser apenas para cartões únicos dentro da série, não para mudanças de gabinete da série inteira
      onProgresso(0.40, 'A cancelar exceções para datas futuras...');
      
      final dataFimSerie = serie.dataFim ?? DateTime(dataRef.year + 1, 12, 31);
      final dataFimProcessamento = DateTime(dataFimSerie.year, dataFimSerie.month, dataFimSerie.day);
      
      // Carregar exceções para datas >= dataRef
      final excecoesFuturas = await SerieService.carregarExcecoes(
        medicoId,
        unidade: unidade,
        dataInicio: dataRefNormalizada,
        dataFim: dataFimProcessamento,
        serieId: serieIdFinal,
        forcarServidor: true,
      );
      
      // #region agent log
      try {
        final excecoesComGabinete = excecoesFuturas.where((e) => e.gabineteId != null && !e.cancelada).length;
        final excecoesSemGabinete = excecoesFuturas.where((e) => e.gabineteId == null && !e.cancelada).length;
        debugPrint('📊 [EXCECOES-FUTURAS] Total: ${excecoesFuturas.length}, com gabinete: $excecoesComGabinete, sem gabinete: $excecoesSemGabinete');
        final logFile = await File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log').open(mode: FileMode.append);
        await logFile.writeString('${jsonEncode({"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":DateTime.now().millisecondsSinceEpoch,"location":"realocacao_serie_service.dart:realocar:EXCECOES_FUTURAS","message":"Exceções futuras carregadas","data":{"totalExcecoes":excecoesFuturas.length,"comGabinete":excecoesComGabinete,"semGabinete":excecoesSemGabinete,"dataRef":"${dataRefNormalizada.year}-${dataRefNormalizada.month}-${dataRefNormalizada.day}","dataFim":"${dataFimSerie.year}-${dataFimSerie.month}-${dataFimSerie.day}"},"sessionId":"debug-session","runId":"run1","hypothesisId":"H1,H2,H4"})}\n');
        await logFile.close();
      } catch (e) {
        debugPrint('❌ [DEBUG-LOG] Erro ao escrever log: $e');
      }
      // #endregion
      
      // Criar mapa de exceções por data para busca rápida
      final excecoesFuturasPorData = <String, ExcecaoSerie>{};
      int excecoesFiltradas = 0;
      for (final excecao in excecoesFuturas) {
        if (excecao.serieId == serieIdFinal && !excecao.cancelada) {
          final dataKey = '${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
          excecoesFuturasPorData[dataKey] = excecao;
          excecoesFiltradas++;
        }
      }
      debugPrint('📋 [MAPEAMENTO-EXCECOES] Exceções filtradas para série $serieIdFinal: $excecoesFiltradas de ${excecoesFuturas.length}');
      
      // Atualizar exceções com gabineteId: null para ter o novo gabineteId
      DateTime dataAtual = dataRefNormalizada;
      int totalExcecoesFuturas = 0;
      
      // Contar quantas exceções precisam ser canceladas (todas as exceções futuras)
      debugPrint('🔍 [CONTAR-EXCECOES] Iniciando contagem de exceções futuras. dataRef: ${dataRefNormalizada.year}-${dataRefNormalizada.month}-${dataRefNormalizada.day}, dataFim: ${dataFimSerie.year}-${dataFimSerie.month}-${dataFimSerie.day}');
      debugPrint('🔍 [CONTAR-EXCECOES] Exceções no mapa: ${excecoesFuturasPorData.length}');
      while (!dataAtual.isAfter(dataFimSerie)) {
        if (verificarSeDataCorrespondeSerie(dataAtual, serie)) {
          final dataKey = '${dataAtual.year}-${dataAtual.month}-${dataAtual.day}';
          final excecaoExistente = excecoesFuturasPorData[dataKey];
          
          // Contar todas as exceções que precisam ser canceladas
          if (excecaoExistente != null) {
            totalExcecoesFuturas++;
            debugPrint('   📋 [CONTAR-EXCECOES] Exceção encontrada para data $dataKey: id=${excecaoExistente.id}, gabinete=${excecaoExistente.gabineteId}');
          }
        }
        dataAtual = dataAtual.add(const Duration(days: 1));
      }
      debugPrint('📊 [CONTAR-EXCECOES] Total de exceções a cancelar: $totalExcecoesFuturas');
      
      // NOVA LÓGICA: Em vez de cancelar exceções, criar/atualizar mudança de gabinete na série
      // Isso armazena apenas a mudança de período, não exceções para cada dia
      debugPrint('🔄 [MUDANCA-GABINETE] Criando mudança de gabinete a partir de ${dataRefNormalizada.day}/${dataRefNormalizada.month}/${dataRefNormalizada.year} para gabinete $gabineteDestino');
      
      // Adicionar mudança de gabinete na série
      serie.adicionarMudancaGabinete(dataRefNormalizada, gabineteDestino);
      
      // Log para Chrome (console.log)
      if (kIsWeb) {
        print('🔄 [MUDANCA-GABINETE] Série ${serie.id}: mudança criada a partir de ${dataRefNormalizada.toIso8601String()} para gabinete $gabineteDestino');
        print('📊 [MUDANCA-GABINETE] Total de mudanças na série: ${serie.mudancasGabinete.length}');
      }
      
      // #region agent log
      try {
        final logFile = await File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log').open(mode: FileMode.append);
        await logFile.writeString('${jsonEncode({"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":DateTime.now().millisecondsSinceEpoch,"location":"realocacao_serie_service.dart:realocar:CRIAR_MUDANCA_GABINETE","message":"Criando mudança de gabinete","data":{"dataRef":"${dataRefNormalizada.year}-${dataRefNormalizada.month}-${dataRefNormalizada.day}","gabineteDestino":gabineteDestino,"totalMudancas":serie.mudancasGabinete.length},"sessionId":"debug-session","runId":"run1","hypothesisId":"MUDANCA-GABINETE"})}\n');
        await logFile.close();
      } catch (e) {
        debugPrint('❌ [DEBUG-LOG] Erro ao escrever log: $e');
      }
      // #endregion

      onProgresso(0.45, 'A atualizar série com mudança de gabinete...');

      // #region agent log
      try {
        final logFile = await File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log').open(mode: FileMode.append);
        await logFile.writeString('${jsonEncode({"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":DateTime.now().millisecondsSinceEpoch,"location":"realocacao_serie_service.dart:realocar:ANTES_SALVAR_SERIE","message":"Antes de salvar série com mudança de gabinete","data":{"serieId":serieIdFinal,"gabineteIdAtual":serie.gabineteId,"gabineteIdNovo":gabineteDestino,"totalMudancas":serie.mudancasGabinete.length},"sessionId":"debug-session","runId":"run1","hypothesisId":"MUDANCA-GABINETE"})}\n');
        await logFile.close();
      } catch (e) {}
      // #endregion

      // NOVA LÓGICA: Salvar série com mudança de gabinete (não atualizar gabineteId padrão)
      // A mudança já foi adicionada via adicionarMudancaGabinete acima
      await SerieService.salvarSerie(serie, unidade: unidade);
      
      // Log para Chrome
      if (kIsWeb) {
        print('✅ [MUDANCA-GABINETE] Série ${serie.id} atualizada no Firestore com ${serie.mudancasGabinete.length} mudança(s) de gabinete');
        print('📊 [MUDANCA-GABINETE] Mudanças: ${serie.mudancasGabinete.map((m) => '${m.dataInicio.day}/${m.dataInicio.month} → ${m.gabineteId}').join(', ')}');
      }
      
      // #region agent log
      try {
        final logFile = await File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log').open(mode: FileMode.append);
        await logFile.writeString('${jsonEncode({"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":DateTime.now().millisecondsSinceEpoch,"location":"realocacao_serie_service.dart:realocar:DEPOIS_SALVAR_SERIE","message":"Depois de salvar série com mudança de gabinete","data":{"serieId":serieIdFinal,"totalMudancas":serie.mudancasGabinete.length},"sessionId":"debug-session","runId":"run1","hypothesisId":"MUDANCA-GABINETE"})}\n');
        await logFile.close();
      } catch (e) {}
      // #endregion

      onProgresso(0.65, 'A invalidar cache...');

      // CORREÇÃO CRÍTICA: Invalidar cache para datas anteriores (onde criamos exceções)
      // Isso garante que as exceções sejam respeitadas ao recarregar
      if (dataRefNormalizada.isAfter(dataInicioSerie)) {
        DateTime dataCacheAnterior = dataInicioSerie;
        while (dataCacheAnterior.isBefore(dataRefNormalizada)) {
          if (verificarSeDataCorrespondeSerie(dataCacheAnterior, serie)) {
            AlocacaoMedicosLogic.invalidateCacheForDay(dataCacheAnterior);
          }
          dataCacheAnterior = dataCacheAnterior.add(const Duration(days: 1));
        }
      }
      
      // Invalidar cache para datas futuras (da data de referência em diante)
      final dataFim = serie.dataFim ?? DateTime(dataRef.year + 1, 12, 31);
      DateTime dataCache = dataRefNormalizada;
      while (dataCache.isBefore(dataFim.add(const Duration(days: 1)))) {
        AlocacaoMedicosLogic.invalidateCacheForDay(dataCache);
        dataCache = dataCache.add(const Duration(days: 1));
      }
      
      onProgresso(0.80, 'A sincronizar...');
      
      // Buscar a série atualizada do servidor para garantir que temos os dados mais recentes
      final seriesAtualizadas = await SerieService.carregarSeries(
        medicoId,
        unidade: unidade,
        forcarServidor: true, // Forçar servidor para garantir dados atualizados
      );
      final serieAtualizada = seriesAtualizadas.firstWhere(
        (s) => s.id == serieIdFinal,
        orElse: () => serie,
      );
      
      // Invalidar cache da série completa (já foi feito acima, mas garantir)
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serieAtualizada, unidade: unidade);

      onProgresso(0.90, 'A concluir...');
      // CORREÇÃO: Chamar onAtualizarEstado ANTES de chegar a 1.0 para garantir que progressbar acompanha recarregamento
      // onAtualizarEstado agora apenas recarrega alocações (não disponibilidades), então é rápido
      try {
        await onAtualizarEstado();
      } catch (e) {
        debugPrint('⚠️ Erro em onAtualizarEstado: $e');
      }
      onProgresso(1.0, 'Completo!');

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

