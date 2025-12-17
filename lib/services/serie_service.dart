// lib/services/serie_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/unidade.dart';

/// Serviço para gerenciar séries de recorrência e exceções no Firestore
class SerieService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      await serieRef.set(serie.toMap());
      debugPrint('✅ Série salva: ${serie.id}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar série: $e');
      rethrow;
    }
  }

  /// Carrega todas as séries de um médico
  static Future<List<SerieRecorrencia>> carregarSeries(
    String medicoId, {
    Unidade? unidade,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      final seriesRef = _firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('series');

      // Se há filtro de data, tentar filtrar na query quando possível
      // Caso contrário, buscar todas e filtrar localmente
      // Buscar apenas séries ativas (filtro na query para reduzir dados transferidos)
      // Usar cache do Firestore quando disponível
      final snapshot = await seriesRef
          .where('ativo', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));
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
        if (dataFim != null && serie.dataInicio.isAfter(dataFim)) {
          continue;
        }

        // Filtrar séries que já terminaram antes do período
        // Se dataFim é null, a série é infinita e deve ser incluída se começou antes ou no período
        if (dataInicio != null) {
          if (serie.dataFim != null && serie.dataFim!.isBefore(dataInicio)) {
            continue; // Série terminou antes do período
          }
          // Se dataFim é null (série infinita) e dataInicio é fornecido,
          // incluir se a série começou antes ou no início do período
          // (já verificado acima com isAfter)
        }

        series.add(serie);
      }

      debugPrint('✅ Séries carregadas: ${series.length}');
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
        // Debug: mostrar anos que serão carregados
        if (forcarServidor) {
          debugPrint(
              '🔍 Carregando exceções do servidor (sem cache) para anos: $anos (período: ${dataInicio.day}/${dataInicio.month}/${dataInicio.year} até ${dataFim.day}/${dataFim.month}/${dataFim.year})');
        }
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
        // Se forçarServidor for true, carregar apenas do servidor (sem cache)
        // Isso é necessário quando uma exceção foi criada recentemente
        final source = forcarServidor ? Source.server : Source.serverAndCache;
        if (forcarServidor) {
          debugPrint(
              '🔍 Carregando exceções do ano $ano do servidor (sem cache) para médico $medicoId');
        }
        final snapshot = await excecoesRef.get(GetOptions(source: source));

        if (forcarServidor) {
          debugPrint(
              '📋 Exceções carregadas do ano $ano: ${snapshot.docs.length} documentos');
        }

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

      // Debug: mostrar exceções com gabineteId para séries mensais
      final excecoesComGabinete =
          excecoes.where((e) => e.gabineteId != null).toList();
      if (excecoesComGabinete.isNotEmpty) {
        debugPrint(
            '✅ Exceções carregadas: ${excecoes.length} total, ${excecoesComGabinete.length} com gabinete');
        for (final ex in excecoesComGabinete) {
          final dataKey =
              '${ex.data.year}-${ex.data.month.toString().padLeft(2, '0')}-${ex.data.day.toString().padLeft(2, '0')}';
          debugPrint(
              '   📋 Exceção: série=${ex.serieId}, data=$dataKey, gabinete=${ex.gabineteId}');
        }
      } else {
        debugPrint('✅ Exceções carregadas: ${excecoes.length}');
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
