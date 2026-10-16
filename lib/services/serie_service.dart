import '../utils/cadastro_persistencia_snapshot.dart';
// lib/services/serie_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import 'cache_version_service.dart';
import 'matriz_distribuicao_cache_service.dart';

/// Serviço para gerenciar séries de recorrência e exceções no Firestore
class SerieService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // Cache de séries por unidade e médico (chave: unidadeId_medicoId)
  // Esses dados mudam raramente, então podemos cacheá-los até serem invalidados
  static final Map<String, List<SerieRecorrencia>> _cacheSeries = {};
  static final Set<String> _cacheSeriesInvalidado = {};
  static final Map<String, Future<void>> _carregamentosSeriesPorUnidade = {};
  static final Map<String, List<ExcecaoSerie>> _cacheExcecoesPorAno = {};
  static final Map<String, Future<List<ExcecaoSerie>>>
      _carregamentosExcecoesPorAno = {};

  static String _chaveSerie(String unidadeId, String medicoId) =>
      '${unidadeId}_$medicoId';

  static String _chaveExcecoesAno(String unidadeId, String medicoId, int ano) =>
      '${unidadeId}_${medicoId}_$ano';

  static List<SerieRecorrencia> _filtrarSeriesPorPeriodo(
    List<SerieRecorrencia> series,
    DateTime? dataInicio,
    DateTime? dataFim,
  ) {
    return series.where((serie) {
      if (dataFim != null) {
        final inicioSerie = DateTime(
          serie.dataInicio.year,
          serie.dataInicio.month,
          serie.dataInicio.day,
        );
        final fimFiltro = DateTime(
          dataFim.year,
          dataFim.month,
          dataFim.day,
        );
        if (inicioSerie.isAfter(fimFiltro)) return false;
      }

      if (dataInicio != null && serie.dataFim != null) {
        final fimSerie = DateTime(
          serie.dataFim!.year,
          serie.dataFim!.month,
          serie.dataFim!.day,
        );
        final inicioFiltro = DateTime(
          dataInicio.year,
          dataInicio.month,
          dataInicio.day,
        );
        if (fimSerie.isBefore(inicioFiltro)) return false;
      }
      return serie.ativo;
    }).toList();
  }

  static void _invalidarCacheExcecoes(
    String unidadeId, {
    String? medicoId,
    int? ano,
  }) {
    final prefixo =
        medicoId == null ? '${unidadeId}_' : '${unidadeId}_${medicoId}_';
    final chavesDisponiveis = <String>{
      ..._cacheExcecoesPorAno.keys,
      ..._carregamentosExcecoesPorAno.keys,
    };
    final chaves = chavesDisponiveis.where((chave) {
      if (!chave.startsWith(prefixo)) return false;
      return ano == null || chave.endsWith('_$ano');
    }).toList();
    for (final chave in chaves) {
      _cacheExcecoesPorAno.remove(chave);
      _carregamentosExcecoesPorAno.remove(chave);
    }
  }

  /// Obtém séries do cache ou retorna null se não estiver em cache
  static List<SerieRecorrencia>? getSeriesFromCache(
      String unidadeId, String medicoId) {
    final key = _chaveSerie(unidadeId, medicoId);
    if (_cacheSeriesInvalidado.contains(key)) return null;
    return _cacheSeries[key];
  }

  /// Armazena séries no cache
  static void setSeriesInCache(
      String unidadeId, String medicoId, List<SerieRecorrencia> series) {
    final key = _chaveSerie(unidadeId, medicoId);
    _cacheSeries[key] = List.from(series);
    _cacheSeriesInvalidado.remove(key);
    _log(
        '💾 [CACHE] Cache de séries atualizado para $key: ${series.length} séries');
  }

  /// Invalida o cache de séries para um médico específico (ou todos se medicoId for null)
  static void invalidateCacheSeries(String unidadeId, [String? medicoId]) {
    MatrizDistribuicaoCacheService.invalidar(unidadeId: unidadeId);
    if (medicoId == null) {
      // Invalidar todas as séries da unidade
      final keysToInvalidate = _cacheSeries.keys
          .where((key) => key.startsWith('${unidadeId}_'))
          .toList();
      for (final key in keysToInvalidate) {
        _cacheSeriesInvalidado.add(key);
        _cacheSeries.remove(key);
      }
      _invalidarCacheExcecoes(unidadeId);
      _log(
          '🗑️ [CACHE] Cache de séries invalidado para unidade $unidadeId (todos os médicos)');
    } else {
      // Invalidar apenas para o médico específico
      final key = _chaveSerie(unidadeId, medicoId);
      _cacheSeriesInvalidado.add(key);
      _cacheSeries.remove(key);
      _invalidarCacheExcecoes(unidadeId, medicoId: medicoId);
      _log('🗑️ [CACHE] Cache de séries invalidado para $key');
    }
  }

  /// Carrega as séries de vários médicos em lotes, evitando uma consulta por
  /// médico. Se a consulta de grupo não estiver disponível, usa o percurso
  /// individual existente apenas para o lote afetado.
  static Future<Map<String, List<SerieRecorrencia>>> carregarSeriesDeMedicos(
    List<String> medicoIds, {
    Unidade? unidade,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool forcarServidor = false,
  }) async {
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    final ids = medicoIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};

    var aplicarForcarServidor = forcarServidor;
    final carregamentoExistente = _carregamentosSeriesPorUnidade[unidadeId];
    if (carregamentoExistente != null) {
      await carregamentoExistente;
      aplicarForcarServidor = false;
    }

    final idsPorCarregar = aplicarForcarServidor
        ? ids
        : ids.where((id) => getSeriesFromCache(unidadeId, id) == null).toList();

    if (idsPorCarregar.isNotEmpty) {
      final carregamento = _carregarSeriesEmLotes(
        idsPorCarregar,
        unidade: unidade,
        forcarServidor: aplicarForcarServidor,
      );
      _carregamentosSeriesPorUnidade[unidadeId] = carregamento;
      try {
        await carregamento;
      } finally {
        if (identical(
          _carregamentosSeriesPorUnidade[unidadeId],
          carregamento,
        )) {
          _carregamentosSeriesPorUnidade.remove(unidadeId);
        }
      }
    }

    return {
      for (final medicoId in ids)
        medicoId: _filtrarSeriesPorPeriodo(
          getSeriesFromCache(unidadeId, medicoId) ?? const [],
          dataInicio,
          dataFim,
        ),
    };
  }

  static Future<void> _carregarSeriesEmLotes(
    List<String> medicoIds, {
    required Unidade? unidade,
    required bool forcarServidor,
  }) async {
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    const tamanhoLote = 10;
    final lotes = <List<String>>[];
    for (var i = 0; i < medicoIds.length; i += tamanhoLote) {
      final fim = (i + tamanhoLote).clamp(0, medicoIds.length);
      lotes.add(medicoIds.sublist(i, fim));
    }

    final source = forcarServidor ? Source.server : Source.serverAndCache;
    await Future.wait(lotes.map((lote) async {
      final seriesPorMedico = {
        for (final medicoId in lote) medicoId: <SerieRecorrencia>[],
      };
      try {
        final snapshot = await _firestore
            .collectionGroup('series')
            .where('medicoId', whereIn: lote)
            .get(GetOptions(source: source));

        for (final doc in snapshot.docs) {
          final segmentos = doc.reference.path.split('/');
          final pertenceUnidade = segmentos.length >= 6 &&
              segmentos[0] == 'unidades' &&
              segmentos[1] == unidadeId &&
              segmentos[2] == 'ocupantes' &&
              segmentos[4] == 'series';
          if (!pertenceUnidade) continue;

          final data = doc.data();
          final serie = SerieRecorrencia.fromMap({...data, 'id': doc.id});
          if (serie.ativo && seriesPorMedico.containsKey(serie.medicoId)) {
            seriesPorMedico[serie.medicoId]!.add(serie);
          }
        }

        for (final entry in seriesPorMedico.entries) {
          final key = _chaveSerie(unidadeId, entry.key);
          _cacheSeries[key] = List<SerieRecorrencia>.from(entry.value);
          _cacheSeriesInvalidado.remove(key);
        }
      } catch (e) {
        _log(
          '⚠️ [SÉRIES-LOTE] Consulta agrupada falhou; a usar fallback para ${lote.length} médicos: $e',
        );
        await Future.wait(lote.map((medicoId) {
          return carregarSeries(
            medicoId,
            unidade: unidade,
            forcarServidor: forcarServidor,
          );
        }));
      }
    }));

    _log(
      '⚡ [SÉRIES-LOTE] ${medicoIds.length} médicos carregados em ${lotes.length} consulta(s) agrupada(s)',
    );
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

      // Invalidar cache de séries após salvar
      invalidateCacheSeries(unidadeId, serie.medicoId);
      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldSeries,
      );
      _log('✅ Série salva: ${serie.id}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar série: $e');
      rethrow;
    }
  }

  /// Só recebe alterações efetivas do editor. Cada lote inclui a versão,
  /// para outros clientes detetarem também uma gravação parcialmente concluída.
  static Future<void> salvarAlteracoes({
    required List<SerieRecorrencia> series,
    required List<ExcecaoSerie> excecoes,
    required String medicoId,
    Unidade? unidade,
    FirebaseFirestore? firestore,
    CadastroPersistenciaSnapshot? originais,
  }) async {
    if (series.isEmpty && excecoes.isEmpty) return;
    final db = firestore ?? _firestore;
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    final unidadeRef = db.collection('unidades').doc(unidadeId);
    final medicoRef = unidadeRef.collection('ocupantes').doc(medicoId);
    final documentos =
        <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>, bool)>[
      for (final serie in series)
        (
          medicoRef.collection('series').doc(serie.id),
          originais?.camposSerie(serie) ?? serie.toMap(),
          originais?.contemSerie(serie.id) ?? false
        ),
      for (final excecao in excecoes)
        (
          medicoRef
              .collection('excecoes')
              .doc('${excecao.data.year}')
              .collection('registos')
              .doc(excecao.id),
          originais?.camposExcecao(excecao) ?? excecao.toMap(),
          originais?.contemExcecao(excecao.id) ?? false
        ),
    ];
    try {
      for (var inicio = 0; inicio < documentos.length; inicio += 400) {
        final batch = db.batch();
        for (final (ref, dados, existia) in documentos.skip(inicio).take(400)) {
          if (existia) {
            // Atualizar só campos editados, preservando alterações concorrentes
            // de outros campos. Um documento entretanto apagado deve dar erro.
            batch.update(ref, dados);
          } else {
            batch.set(ref, dados, SetOptions(merge: true));
          }
        }
        batch.set(
            unidadeRef.collection('cache_control').doc('global'),
            {
              CacheVersionService.fieldSeries: FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        await batch.commit();
      }
    } finally {
      invalidateCacheSeries(unidadeId, medicoId);
      for (final serie in series) {
        AlocacaoMedicosLogic.invalidateCacheParaSerie(serie, unidade: unidade);
      }
      for (final excecao in excecoes) {
        AlocacaoMedicosLogic.invalidateCacheForDay(excecao.data);
      }
    }
  }

  /// A mudança de período substitui os gabinetes pontuais já existentes.
  /// Atualiza apenas gabineteId: ausências, cartões ocultos e horários mantêm-se.
  static Future<void> salvarRealocacaoSerie(
    SerieRecorrencia serie,
    DateTime dataRef,
    String gabineteDestino, {
    Unidade? unidade,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? _firestore;
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    final unidadeRef = db.collection('unidades').doc(unidadeId);
    final medicoRef = unidadeRef.collection('ocupantes').doc(serie.medicoId);
    final inicio = DateTime(dataRef.year, dataRef.month, dataRef.day);
    // Inclui todos os anos futuros, sem transferir o histórico anterior.
    final snapshot = await db
        .collectionGroup('registos')
        .where('serieId', isEqualTo: serie.id)
        .where('data', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .get(const GetOptions(source: Source.server));
    final prefixo = '${medicoRef.path}/excecoes/';
    final alteracoes = snapshot.docs
        .where((doc) =>
            doc.reference.path.startsWith(prefixo) &&
            ExcecaoSerie.fromMap(doc.data()).deveSubstituirGabineteNaRealocacao(
              serieId: serie.id,
              dataRef: inicio,
              gabineteDestino: gabineteDestino,
            ))
        .toList();
    final totalLotes = (alteracoes.length / 400).ceil().clamp(1, 1000000);
    try {
      for (var lote = 0; lote < totalLotes; lote++) {
        final batch = db.batch();
        for (final doc in alteracoes.skip(lote * 400).take(400)) {
          batch.update(doc.reference, {'gabineteId': gabineteDestino});
        }
        if (lote == totalLotes - 1) {
          // Para até 400 exceções, regra e exceções mudam atomicamente.
          // Não sobrescrever os horários nem outros campos da série.
          batch.update(medicoRef.collection('series').doc(serie.id), {
            'mudancasGabinete':
                serie.mudancasGabinete.map((m) => m.toMap()).toList(),
          });
        }
        batch.set(
            unidadeRef.collection('cache_control').doc('global'),
            {
              CacheVersionService.fieldSeries: FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        await batch.commit();
      }
    } finally {
      invalidateCacheSeries(unidadeId, serie.medicoId);
      AlocacaoMedicosLogic.invalidateCacheFromDate(inicio);
    }
  }

  /// Persiste, numa única operação, apenas a numeração das séries antigas.
  /// Não regrava os restantes campos e por isso não interfere com alterações
  /// simultâneas de horários, gabinete ou período.
  static Future<void> salvarNumeracaoSeries(
    List<SerieRecorrencia> series, {
    Unidade? unidade,
  }) async {
    final seriesNumeradas =
        series.where((s) => s.numeroNoTipo != null).toList();
    if (seriesNumeradas.isEmpty) return;

    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      final batch = _firestore.batch();

      for (final serie in seriesNumeradas) {
        final serieRef = _firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes')
            .doc(serie.medicoId)
            .collection('series')
            .doc(serie.id);
        batch.update(
          serieRef,
          {'parametros.numeroNoTipo': serie.numeroNoTipo},
        );
      }

      await batch.commit();

      for (final medicoId in seriesNumeradas.map((s) => s.medicoId).toSet()) {
        invalidateCacheSeries(unidadeId, medicoId);
      }
      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldSeries,
      );
      _log('✅ Numeração migrada em ${seriesNumeradas.length} série(s)');
    } catch (e) {
      debugPrint('❌ Erro ao migrar numeração das séries: $e');
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
          _log(
              '💾 [CACHE] Usando cache de séries para $unidadeId médico $medicoId');
          // Filtrar por período se fornecido (mesmo com cache, precisamos filtrar)
          // CORREÇÃO CRÍTICA: Normalizar datas para comparação correta
          final seriesFiltradas = <SerieRecorrencia>[];
          for (final serie in cached) {
            // Filtrar por período se fornecido
            // CORREÇÃO: Quando dataInicio é null, significa que queremos TODAS as séries que começaram antes ou no dataFim
            // Mesma lógica do código acima para garantir consistência
            if (dataFim != null && dataInicio != null) {
              // Apenas filtrar quando AMBOS estão definidos (período específico)
              final serieDataInicioNormalizada = DateTime(serie.dataInicio.year,
                  serie.dataInicio.month, serie.dataInicio.day);
              final dataFimNormalizada =
                  DateTime(dataFim.year, dataFim.month, dataFim.day);
              if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
                continue;
              }
            } else if (dataFim != null && dataInicio == null) {
              // Quando dataInicio é null mas dataFim está definido, apenas filtrar séries que começaram DEPOIS do dataFim
              final serieDataInicioNormalizada = DateTime(serie.dataInicio.year,
                  serie.dataInicio.month, serie.dataInicio.day);
              final dataFimNormalizada =
                  DateTime(dataFim.year, dataFim.month, dataFim.day);
              if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
                continue;
              }
            }
            if (dataInicio != null) {
              if (serie.dataFim != null) {
                final serieDataFimNormalizada = DateTime(serie.dataFim!.year,
                    serie.dataFim!.month, serie.dataFim!.day);
                final dataInicioNormalizada =
                    DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
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
        _log(
            '🔄 [FORÇAR SERVIDOR] Buscando séries do servidor para $unidadeId médico $medicoId (cache ignorado)');
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

      final source = forcarServidor ? Source.server : Source.serverAndCache;
      final series = <SerieRecorrencia>[];
      final seriesIdsProcessados = <String>{};
      bool usarQueryOtimizada = false;

      // OTIMIZAÇÃO OPCIONAL: Tentar usar queries otimizadas quando há período definido
      // Isso reduz dados transferidos do Firestore, especialmente séries antigas que já terminaram
      // Se falhar, usa a query original (fallback seguro)
      // CORREÇÃO: Só usar queries otimizadas quando AMBOS dataInicio E dataFim estão definidos
      // Caso contrário, usar query original para evitar loops infinitos

      if (dataInicio != null && dataFim != null) {
        // Calcular data mínima para filtrar séries que terminaram antes do período
        final dataMinimaFiltro = dataInicio;

        _log(
            '⚡ [OTIMIZAÇÃO] Tentando usar queries otimizadas para período: ${dataInicio.toString()} até ${dataFim.toString()}');

        try {
          // Query 1: Séries com dataFim >= dataMinimaFiltro (séries que ainda estão ativas no período)
          // Isso exclui séries que já terminaram antes do período
          final snapshotComDataFim = await seriesRef
              .where('ativo', isEqualTo: true)
              .where('dataFim',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(dataMinimaFiltro))
              .get(GetOptions(source: source));

          _log(
              '📊 [OTIMIZAÇÃO] Query 1 (com dataFim): ${snapshotComDataFim.docs.length} séries encontradas');

          for (final doc in snapshotComDataFim.docs) {
            if (seriesIdsProcessados.contains(doc.id)) continue;
            final data = doc.data();
            final serie = SerieRecorrencia.fromMap({...data, 'id': doc.id});
            if (serie.ativo) {
              series.add(serie);
              seriesIdsProcessados.add(serie.id);
            }
          }

          // Query 2: Séries infinitas (dataFim == null) - sempre relevantes se começaram antes ou no período
          // Essas séries continuam indefinidamente, então precisamos incluí-las
          final snapshotInfinitas = await seriesRef
              .where('ativo', isEqualTo: true)
              .where('dataFim', isNull: true)
              .get(GetOptions(source: source));

          _log(
              '📊 [OTIMIZAÇÃO] Query 2 (infinitas): ${snapshotInfinitas.docs.length} séries encontradas');

          for (final doc in snapshotInfinitas.docs) {
            if (seriesIdsProcessados.contains(doc.id)) continue;
            final data = doc.data();
            final serie = SerieRecorrencia.fromMap({...data, 'id': doc.id});
            if (serie.ativo) {
              series.add(serie);
              seriesIdsProcessados.add(serie.id);
            }
          }

          usarQueryOtimizada = true;
          _log(
              '✅ [OTIMIZAÇÃO] Queries otimizadas executadas com sucesso! Total: ${series.length} séries');
        } catch (e) {
          // Se as queries otimizadas falharem (ex: índice não existe), usar query original
          _log(
              '⚠️ [OTIMIZAÇÃO] Queries otimizadas falharam ($e), usando query original (fallback seguro)');

          series.clear();
          seriesIdsProcessados.clear();
          usarQueryOtimizada = false;
        }
      }

      // Se não usou query otimizada (ou falhou), usar query original
      if (!usarQueryOtimizada) {
        _log(
            '📊 [QUERY ORIGINAL] Buscando todas as séries ativas (sem filtro no Firestore)');
        final snapshot = await seriesRef
            .where('ativo', isEqualTo: true)
            .get(GetOptions(source: source));

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final serie = SerieRecorrencia.fromMap({...data, 'id': doc.id});
          if (serie.ativo) {
            series.add(serie);
          }
        }
      }

      // Aplicar filtros finais localmente para garantir precisão
      // IMPORTANTE: Esta lógica NÃO muda - é a mesma de antes!
      // Apenas otimizamos a query do Firestore, mas a filtragem final é igual
      final seriesFiltradas = <SerieRecorrencia>[];
      for (final serie in series) {
        // Filtrar por período se fornecido
        // IMPORTANTE: Para séries infinitas (dataFim == null), sempre incluir se começaram antes ou no período
        // CORREÇÃO CRÍTICA: Normalizar datas para comparação correta (sem hora/minutos/segundos)
        // CORREÇÃO: Quando dataInicio é null, significa que queremos TODAS as séries que começaram antes ou no dataFim
        // Não filtrar por dataFim se dataInicio é null (queremos séries antigas também)
        if (dataFim != null && dataInicio != null) {
          // Apenas filtrar quando AMBOS estão definidos (período específico)
          final serieDataInicioNormalizada = DateTime(serie.dataInicio.year,
              serie.dataInicio.month, serie.dataInicio.day);
          final dataFimNormalizada =
              DateTime(dataFim.year, dataFim.month, dataFim.day);
          if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
            continue;
          }
        } else if (dataFim != null && dataInicio == null) {
          // Quando dataInicio é null mas dataFim está definido, apenas filtrar séries que começaram DEPOIS do dataFim
          // Isso permite incluir séries que começaram antes (ex: fevereiro quando navegamos em março)
          final serieDataInicioNormalizada = DateTime(serie.dataInicio.year,
              serie.dataInicio.month, serie.dataInicio.day);
          final dataFimNormalizada =
              DateTime(dataFim.year, dataFim.month, dataFim.day);
          if (serieDataInicioNormalizada.isAfter(dataFimNormalizada)) {
            continue;
          }
        }

        // Filtrar séries que já terminaram antes do período
        // Se dataFim é null, a série é infinita e deve ser incluída se começou antes ou no período
        if (dataInicio != null) {
          if (serie.dataFim != null) {
            final serieDataFimNormalizada = DateTime(
                serie.dataFim!.year, serie.dataFim!.month, serie.dataFim!.day);
            final dataInicioNormalizada =
                DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
            if (serieDataFimNormalizada.isBefore(dataInicioNormalizada)) {
              continue; // Série terminou antes do período
            }
          }
          // Se dataFim é null (série infinita) e dataInicio é fornecido,
          // incluir se a série começou antes ou no início do período
          // (já verificado acima com isAfter)
        }

        seriesFiltradas.add(serie);
      }

      _log(
          '✅ [RESULTADO FINAL] Total de séries após filtros: ${seriesFiltradas.length} (de ${series.length} carregadas do Firestore)');

      // Armazenar no cache (armazenar todas as séries carregadas, não apenas as filtradas)
      // O filtro por período será feito quando necessário
      setSeriesInCache(unidadeId, medicoId, series);

      return seriesFiltradas;
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
        _log('✅ Série removida permanentemente: $serieId');
      } else {
        await serieRef.update({'ativo': false});
        _log('✅ Série desativada: $serieId');
      }

      // Invalidar cache de séries após remover
      invalidateCacheSeries(unidadeId, medicoId);
      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldSeries,
      );
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

      _invalidarCacheExcecoes(
        unidadeId,
        medicoId: medicoId,
        ano: excecao.data.year,
      );

      // CORREÇÃO CRÍTICA: Invalidar cache quando uma exceção é salva
      AlocacaoMedicosLogic.invalidateCacheForDay(excecao.data);
      AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(excecao.data.year, 1, 1));
      // CORREÇÃO: O cache de exceções já é limpo em invalidateCacheForDay
      // (_cacheExcecoes.clear() é chamado lá)
      // NOTA: Não invalidar cache de séries aqui - exceções não mudam as séries em si

      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldSeries,
      );
      _log('✅ Exceção salva: ${excecao.id}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar exceção: $e');
      rethrow;
    }
  }

  /// Consulta pontual sem carregar todo o histórico anual do médico.
  static Future<List<ExcecaoSerie>> carregarExcecoesDaData({
    required String medicoId,
    required String serieId,
    required DateTime data,
    Unidade? unidade,
    FirebaseFirestore? firestore,
  }) async {
    final dia = DateTime(data.year, data.month, data.day);
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    final snapshot = await (firestore ?? _firestore)
        .collection('unidades')
        .doc(unidadeId)
        .collection('ocupantes')
        .doc(medicoId)
        .collection('excecoes')
        .doc('${dia.year}')
        .collection('registos')
        .where('data', isEqualTo: dia.toIso8601String())
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((d) => ExcecaoSerie.fromMap({...d.data(), 'id': d.id}))
        .where((e) => e.serieId == serieId)
        .toList();
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
        final excecoesAno = await _carregarExcecoesAno(
          unidadeId: unidadeId,
          medicoId: medicoId,
          ano: ano,
          forcarServidor: forcarServidor,
        );

        for (final excecao in excecoesAno) {
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

  static Future<List<ExcecaoSerie>> _carregarExcecoesAno({
    required String unidadeId,
    required String medicoId,
    required int ano,
    required bool forcarServidor,
  }) async {
    final key = _chaveExcecoesAno(unidadeId, medicoId, ano);
    if (!forcarServidor) {
      final cached = _cacheExcecoesPorAno[key];
      if (cached != null) return List<ExcecaoSerie>.from(cached);
    }

    final emCurso = _carregamentosExcecoesPorAno[key];
    if (emCurso != null) {
      return List<ExcecaoSerie>.from(await emCurso);
    }

    final carregamento = (() async {
      final excecoesRef = _firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('excecoes')
          .doc(ano.toString())
          .collection('registos');
      final source = forcarServidor ? Source.server : Source.serverAndCache;
      final snapshot = await excecoesRef.get(GetOptions(source: source));
      return snapshot.docs
          .map((doc) => ExcecaoSerie.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    })();

    _carregamentosExcecoesPorAno[key] = carregamento;
    try {
      final resultado = await carregamento;
      _cacheExcecoesPorAno[key] = List<ExcecaoSerie>.from(resultado);
      return List<ExcecaoSerie>.from(resultado);
    } finally {
      if (identical(_carregamentosExcecoesPorAno[key], carregamento)) {
        _carregamentosExcecoesPorAno.remove(key);
      }
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

      _invalidarCacheExcecoes(
        unidadeId,
        medicoId: medicoId,
        ano: data.year,
      );

      // CORREÇÃO CRÍTICA: Invalidar cache quando uma exceção é removida
      AlocacaoMedicosLogic.invalidateCacheForDay(data);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldSeries,
      );
      _log('✅ Exceção removida: $excecaoId');
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
