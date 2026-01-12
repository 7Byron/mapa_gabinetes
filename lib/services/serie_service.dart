// lib/services/serie_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../utils/debug_log_file.dart';

/// Serviço para gerenciar séries de recorrência e exceções no Firestore
class SerieService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache de séries por unidade e médico (chave: unidadeId_medicoId)
  // Esses dados mudam raramente, então podemos cacheá-los até serem invalidados
  static final Map<String, List<SerieRecorrencia>> _cacheSeries = {};
  static final Set<String> _cacheSeriesInvalidado = {};

  /// Obtém séries do cache ou retorna null se não estiver em cache
  static List<SerieRecorrencia>? getSeriesFromCache(String unidadeId, String medicoId) {
    final key = '${unidadeId}_$medicoId';
    if (_cacheSeriesInvalidado.contains(key)) return null;
    return _cacheSeries[key];
  }

  /// Armazena séries no cache
  static void setSeriesInCache(String unidadeId, String medicoId, List<SerieRecorrencia> series) {
    final key = '${unidadeId}_$medicoId';
    _cacheSeries[key] = List.from(series);
    _cacheSeriesInvalidado.remove(key);
    debugPrint('💾 [CACHE] Cache de séries atualizado para $key: ${series.length} séries');
  }

  /// Invalida o cache de séries para um médico específico (ou todos se medicoId for null)
  static void invalidateCacheSeries(String unidadeId, [String? medicoId]) {
    if (medicoId == null) {
      // Invalidar todas as séries da unidade
      final keysToInvalidate = _cacheSeries.keys.where((key) => key.startsWith('${unidadeId}_')).toList();
      for (final key in keysToInvalidate) {
        _cacheSeriesInvalidado.add(key);
        _cacheSeries.remove(key);
      }
      debugPrint('🗑️ [CACHE] Cache de séries invalidado para unidade $unidadeId (todos os médicos)');
    } else {
      // Invalidar apenas para o médico específico
      final key = '${unidadeId}_$medicoId';
      _cacheSeriesInvalidado.add(key);
      _cacheSeries.remove(key);
      debugPrint('🗑️ [CACHE] Cache de séries invalidado para $key');
    }
  }

  /// Salva uma série de recorrência
  static Future<void> salvarSerie(
    SerieRecorrencia serie, {
    Unidade? unidade,
  }) async {
    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      final serieRef = _firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(serie.medicoId)
          .collection('series')
          .doc(serie.id);

      final serieMap = serie.toMap();
      await serieRef.set(serieMap);
      
      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_service.dart:salvarSerie',
          'message': 'Série salva no Firestore',
          'data': {
            'serieId': serie.id,
            'medicoId': serie.medicoId,
            'gabineteId': serie.gabineteId,
            'unidadeId': unidadeId,
            'hypothesisId': 'F'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion
      
      // Invalidar cache de séries após salvar
      invalidateCacheSeries(unidadeId, serie.medicoId);
      debugPrint('✅ Série salva: ${serie.id}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar série: $e');
      rethrow;
    }
  }

  /// Carrega todas as séries de um médico
  /// OTIMIZAÇÃO: Usa cache persistente para evitar buscar do Firestore a cada mudança de dia
  /// CORREÇÃO: Quando não há cache válido, forçar busca do servidor para garantir dados atualizados
  static Future<List<SerieRecorrencia>> carregarSeries(
    String medicoId, {
    Unidade? unidade,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool forcarServidor = false, // Novo parâmetro para forçar busca do servidor
  }) async {
    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      // CORREÇÃO CRÍTICA: Se forçar servidor, ignorar cache e buscar diretamente
      // Isso é importante quando a aplicação é reaberta ou quando se suspeita de dados desatualizados
      if (!forcarServidor) {
        // Verificar cache primeiro
        final cached = getSeriesFromCache(unidadeId, medicoId);
        if (cached != null) {
          debugPrint('💾 [CACHE] Usando cache de séries para $unidadeId médico $medicoId');
          // Filtrar por período se fornecido (mesmo com cache, precisamos filtrar)
          // CORREÇÃO CRÍTICA: Normalizar datas para comparação correta
          final seriesFiltradas = <SerieRecorrencia>[];
          for (final serie in cached) {
            // Filtrar por período se fornecido
            // CORREÇÃO: Quando dataInicio é null, significa que queremos TODAS as séries que começaram antes ou no dataFim
            // Mesma lógica do código acima para garantir consistência
            if (dataFim != null && dataInicio != null) {
              // Apenas filtrar quando AMBOS estão definidos (período específico)
              final serieDataInicioNormalizada = DateTime(serie.dataInicio.year, serie.dataInicio.month, serie.dataInicio.day);
              final dataFimNormalizada = DateTime(dataFim.year, dataFim.month, dataFim.day);
              if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
                continue;
              }
            } else if (dataFim != null && dataInicio == null) {
              // Quando dataInicio é null mas dataFim está definido, apenas filtrar séries que começaram DEPOIS do dataFim
              final serieDataInicioNormalizada = DateTime(serie.dataInicio.year, serie.dataInicio.month, serie.dataInicio.day);
              final dataFimNormalizada = DateTime(dataFim.year, dataFim.month, dataFim.day);
              if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
                continue;
              }
            }
            if (dataInicio != null) {
              if (serie.dataFim != null) {
                final serieDataFimNormalizada = DateTime(serie.dataFim!.year, serie.dataFim!.month, serie.dataFim!.day);
                final dataInicioNormalizada = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
                if (serieDataFimNormalizada.isBefore(dataInicioNormalizada)) {
                  continue;
                }
              }
            }
            seriesFiltradas.add(serie);
          }
          return seriesFiltradas;
        }
      } else {
        debugPrint('🔄 [FORÇAR SERVIDOR] Buscando séries do servidor para $unidadeId médico $medicoId (cache ignorado)');
      }

      final seriesRef = _firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('series');

      // CORREÇÃO CRÍTICA: Se não há cache válido ou forçar servidor, buscar do servidor
      // para garantir que dados recém-salvos sejam carregados após reabrir a aplicação
      // O cache do Firestore pode estar desatualizado quando a aplicação é reaberta
      // Se há filtro de data, tentar filtrar na query quando possível
      // Caso contrário, buscar todas e filtrar localmente
      // Buscar apenas séries ativas (filtro na query para reduzir dados transferidos)
      // CORREÇÃO: Usar Source.server quando forçar servidor ou quando não há cache válido
      
      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_service.dart:carregarSeries-antes-query',
          'message': 'Antes de buscar séries do Firestore',
          'data': {
            'medicoId': medicoId,
            'unidadeId': unidadeId,
            'forcarServidor': forcarServidor,
            'hypothesisId': 'G'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion
      final source = forcarServidor ? Source.server : Source.serverAndCache;
      final snapshot = await seriesRef
          .where('ativo', isEqualTo: true)
          .get(GetOptions(source: source));
      final series = <SerieRecorrencia>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final serie = SerieRecorrencia.fromMap({...data, 'id': doc.id});

        // Filtrar séries inativas
        if (!serie.ativo) {
          continue;
        }

        // Filtrar por período se fornecido
        // IMPORTANTE: Para séries infinitas (dataFim == null), sempre incluir se começaram antes ou no período
        // CORREÇÃO CRÍTICA: Normalizar datas para comparação correta (sem hora/minutos/segundos)
        // CORREÇÃO: Quando dataInicio é null, significa que queremos TODAS as séries que começaram antes ou no dataFim
        // Não filtrar por dataFim se dataInicio é null (queremos séries antigas também)
        if (dataFim != null && dataInicio != null) {
          // Apenas filtrar quando AMBOS estão definidos (período específico)
          final serieDataInicioNormalizada = DateTime(serie.dataInicio.year, serie.dataInicio.month, serie.dataInicio.day);
          final dataFimNormalizada = DateTime(dataFim.year, dataFim.month, dataFim.day);
          if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
            // #region agent log
            try {
              final logEntry = {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'location': 'serie_service.dart:153',
                'message': '🔴 [HYP-B] Série filtrada - começou depois do dataFim',
                'data': {
                  'serieId': serie.id,
                  'medicoId': serie.medicoId,
                  'serieTipo': serie.tipo,
                  'serieDataInicio': serieDataInicioNormalizada.toString(),
                  'dataFim': dataFimNormalizada.toString(),
                  'hypothesisId': 'B'
                },
                'sessionId': 'debug-session',
                'runId': 'run1',
              };
              writeLogToFile(jsonEncode(logEntry));
            } catch (e) {}
            // #endregion
            continue;
          }
        } else if (dataFim != null && dataInicio == null) {
          // Quando dataInicio é null mas dataFim está definido, apenas filtrar séries que começaram DEPOIS do dataFim
          // Isso permite incluir séries que começaram antes (ex: fevereiro quando navegamos em março)
          final serieDataInicioNormalizada = DateTime(serie.dataInicio.year, serie.dataInicio.month, serie.dataInicio.day);
          final dataFimNormalizada = DateTime(dataFim.year, dataFim.month, dataFim.day);
          if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
            // #region agent log
            try {
              final logEntry = {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'location': 'serie_service.dart:153',
                'message': '🔴 [HYP-B] Série filtrada - começou depois do dataFim (dataInicio null)',
                'data': {
                  'serieId': serie.id,
                  'medicoId': serie.medicoId,
                  'serieTipo': serie.tipo,
                  'serieDataInicio': serieDataInicioNormalizada.toString(),
                  'dataFim': dataFimNormalizada.toString(),
                  'hypothesisId': 'B'
                },
                'sessionId': 'debug-session',
                'runId': 'run1',
              };
              writeLogToFile(jsonEncode(logEntry));
            } catch (e) {}
            // #endregion
            continue;
          }
        }

        // Filtrar séries que já terminaram antes do período
        // Se dataFim é null, a série é infinita e deve ser incluída se começou antes ou no período
        if (dataInicio != null) {
          if (serie.dataFim != null) {
            final serieDataFimNormalizada = DateTime(serie.dataFim!.year, serie.dataFim!.month, serie.dataFim!.day);
            final dataInicioNormalizada = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
            if (serieDataFimNormalizada.isBefore(dataInicioNormalizada)) {
              // #region agent log
              try {
                final logEntry = {
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'location': 'serie_service.dart:159',
                  'message': '🔴 [HYP-B] Série filtrada - terminou antes do dataInicio',
                  'data': {
                    'serieId': serie.id,
                    'medicoId': serie.medicoId,
                    'serieTipo': serie.tipo,
                    'serieDataFim': serieDataFimNormalizada.toString(),
                    'dataInicio': dataInicioNormalizada.toString(),
                    'hypothesisId': 'B'
                  },
                  'sessionId': 'debug-session',
                  'runId': 'run1',
                };
                writeLogToFile(jsonEncode(logEntry));
              } catch (e) {}
              // #endregion
              continue; // Série terminou antes do período
            }
          }
          // Se dataFim é null (série infinita) e dataInicio é fornecido,
          // incluir se a série começou antes ou no início do período
          // (já verificado acima com isAfter)
        }

        // #region agent log
        try {
          final logEntry = {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'location': 'serie_service.dart:168',
            'message': '🟢 [HYP-B] Série adicionada à lista de retorno',
            'data': {
              'serieId': serie.id,
              'medicoId': serie.medicoId,
              'tipo': serie.tipo,
              'dataInicio': serie.dataInicio.toString(),
              'dataFim': serie.dataFim?.toString() ?? 'null',
              'ativo': serie.ativo,
              'hypothesisId': 'B'
            },
            'sessionId': 'debug-session',
            'runId': 'run1',
          };
          writeLogToFile(jsonEncode(logEntry));
        } catch (e) {}
        // #endregion

        series.add(serie);
      }

      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_service.dart:185',
          'message': '🟢 [HYP-B] Total de séries retornadas',
          'data': {
            'medicoId': medicoId,
            'totalSeries': series.length,
            'tipos': series.map((s) => s.tipo).toList(),
            'serieIds': series.map((s) => s.id).toList(),
            'hypothesisId': 'B'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion

      // Armazenar no cache (armazenar todas as séries, não apenas as filtradas)
      // O filtro por período será feito quando necessário
      setSeriesInCache(unidadeId, medicoId, series);

      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_service.dart:carregarSeries-retornar',
          'message': 'Séries carregadas do Firestore e retornadas',
          'data': {
            'medicoId': medicoId,
            'unidadeId': unidadeId,
            'forcarServidor': forcarServidor,
            'totalSeries': series.length,
            'seriesIds': series.map((s) => s.id).toList(),
            'seriesGabineteIds': series.map((s) => s.gabineteId).toList(),
            'hypothesisId': 'G'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion

      return series;
    } catch (e) {
      debugPrint('❌ Erro ao carregar séries: $e');
      return [];
    }
  }

  /// Remove uma série (marca como inativa)
  static Future<void> removerSerie(
    String serieId,
    String medicoId, {
    Unidade? unidade,
    bool permanente = false,
  }) async {
    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      final serieRef = _firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('series')
          .doc(serieId);

      if (permanente) {
        await serieRef.delete();
        debugPrint('✅ Série removida permanentemente: $serieId');
      } else {
        await serieRef.update({'ativo': false});
        debugPrint('✅ Série desativada: $serieId');
      }
      
      // Invalidar cache de séries após remover
      invalidateCacheSeries(unidadeId, medicoId);
    } catch (e) {
      debugPrint('❌ Erro ao remover série: $e');
      rethrow;
    }
  }

  /// Salva uma exceção
  static Future<void> salvarExcecao(
    ExcecaoSerie excecao,
    String medicoId, {
    Unidade? unidade,
  }) async {
    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      final ano = excecao.data.year.toString();

      final excecaoRef = _firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('excecoes')
          .doc(ano)
          .collection('registos')
          .doc(excecao.id);

      await excecaoRef.set(excecao.toMap());
      
      // CORREÇÃO CRÍTICA: Invalidar cache quando uma exceção é salva
      AlocacaoMedicosLogic.invalidateCacheForDay(excecao.data);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(excecao.data.year, 1, 1));
      // CORREÇÃO: O cache de exceções já é limpo em invalidateCacheForDay
      // (_cacheExcecoes.clear() é chamado lá)
      // NOTA: Não invalidar cache de séries aqui - exceções não mudam as séries em si
      
      debugPrint('✅ Exceção salva: ${excecao.id}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar exceção: $e');
      rethrow;
    }
  }

  /// Carrega exceções de um médico em um período
  static Future<List<ExcecaoSerie>> carregarExcecoes(
    String medicoId, {
    Unidade? unidade,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? serieId,
    bool forcarServidor =
        false, // Novo parâmetro para forçar carregamento do servidor
  }) async {
    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      final excecoes = <ExcecaoSerie>[];

      // Determinar anos a carregar
      final anos = <int>{};
      if (dataInicio != null && dataFim != null) {
        for (int ano = dataInicio.year; ano <= dataFim.year; ano++) {
          anos.add(ano);
        }
        // (removido para melhorar performance e reduzir ruído no terminal)
      } else {
        anos.add(DateTime.now().year);
      }

      // Carregar exceções de cada ano
      for (final ano in anos) {
        final excecoesRef = _firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes')
            .doc(medicoId)
            .collection('excecoes')
            .doc(ano.toString())
            .collection('registos');

        // Buscar todas as exceções e filtrar localmente para evitar índices compostos
        // Usar cache do Firestore para melhor performance
        // Só forçar servidor se realmente necessário (ex: após criar exceção)
        final source = forcarServidor ? Source.server : Source.serverAndCache;
        final snapshot = await excecoesRef.get(GetOptions(source: source));

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final excecao = ExcecaoSerie.fromMap({...data, 'id': doc.id});

          // Filtrar por serieId se fornecido
          if (serieId != null && excecao.serieId != serieId) {
            continue;
          }

          // Filtrar por período se fornecido
          if (dataInicio != null && excecao.data.isBefore(dataInicio)) {
            continue;
          }

          if (dataFim != null && excecao.data.isAfter(dataFim)) {
            continue;
          }

          excecoes.add(excecao);
        }
      }

      return excecoes;
    } catch (e) {
      debugPrint('❌ Erro ao carregar exceções: $e');
      return [];
    }
  }

  /// Remove uma exceção
  static Future<void> removerExcecao(
    String excecaoId,
    String medicoId,
    DateTime data, {
    Unidade? unidade,
  }) async {
    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      final ano = data.year.toString();

      final excecaoRef = _firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('excecoes')
          .doc(ano)
          .collection('registos')
          .doc(excecaoId);

      await excecaoRef.delete();
      
      // CORREÇÃO CRÍTICA: Invalidar cache quando uma exceção é removida
      AlocacaoMedicosLogic.invalidateCacheForDay(data);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));
      
      debugPrint('✅ Exceção removida: $excecaoId');
    } catch (e) {
      debugPrint('❌ Erro ao remover exceção: $e');
      rethrow;
    }
  }

  /// Converte uma disponibilidade antiga em uma série (migração)
  static Future<SerieRecorrencia?> converterParaSerie(
    String disponibilidadeId,
    String medicoId,
    DateTime data,
    String tipo,
    List<String> horarios, {
    Unidade? unidade,
  }) async {
    try {
      // Criar série baseada na disponibilidade
      final serieId = 'serie_${DateTime.now().millisecondsSinceEpoch}';
      final serie = SerieRecorrencia(
        id: serieId,
        medicoId: medicoId,
        dataInicio: data,
        tipo: tipo,
        horarios: horarios,
        parametros: tipo == 'Consecutivo' ? {'numeroDias': 5} : {},
      );

      await salvarSerie(serie, unidade: unidade);
      return serie;
    } catch (e) {
      debugPrint('❌ Erro ao converter para série: $e');
      return null;
    }
  }
}
