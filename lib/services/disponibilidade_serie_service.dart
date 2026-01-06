// lib/services/disponibilidade_serie_service.dart

import 'package:flutter/foundation.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import 'serie_service.dart';
import '../utils/alocacao_medicos_logic.dart';

/// Serviço para criar séries de recorrência em vez de cartões individuais
class DisponibilidadeSerieService {
  /// Cria uma série de recorrência baseada nos parâmetros
  /// Retorna a série criada e uma lista de disponibilidades geradas (para compatibilidade)
  static Future<SerieRecorrencia> criarSerie({
    required String medicoId,
    required DateTime dataInicial,
    required String tipo,
    required List<String> horarios,
    Unidade? unidade,
    DateTime? dataFim,
    String? gabineteId,
    bool usarSerie =
        true, // Se false, cria cartões individuais (compatibilidade)
    Map<String, dynamic>? parametros,
  }) async {
    // Se não deve usar série, retornar série vazia (será tratado pelo código antigo)
    if (!usarSerie) {
      throw UnimplementedError('Modo de compatibilidade não implementado aqui');
    }

    // Criar ID único para a série
    final serieId = 'serie_${DateTime.now().millisecondsSinceEpoch}';

    // Preparar parâmetros específicos
    Map<String, dynamic> parametrosFinal = parametros ?? {};
    if (tipo.startsWith('Consecutivo:')) {
      final numeroDiasStr = tipo.split(':')[1];
      final numeroDias = int.tryParse(numeroDiasStr) ?? 5;
      parametrosFinal['numeroDias'] = numeroDias;
      tipo = 'Consecutivo';
    }

    // Criar série
    final serie = SerieRecorrencia(
      id: serieId,
      medicoId: medicoId,
      dataInicio: dataInicial,
      dataFim: dataFim,
      tipo: tipo,
      horarios: horarios,
      gabineteId: gabineteId,
      parametros: parametrosFinal,
      ativo: true,
    );

    // Salvar no Firestore
    await SerieService.salvarSerie(serie, unidade: unidade);

    debugPrint(
        '✅ Série criada: $tipo para médico $medicoId a partir de ${dataInicial.day}/${dataInicial.month}/${dataInicial.year}');

    return serie;
  }

  /// Converte uma disponibilidade antiga em uma série (migração)
  static Future<SerieRecorrencia?> converterDisponibilidadeParaSerie(
    Disponibilidade disponibilidade, {
    Unidade? unidade,
  }) async {
    // Se já é única, não precisa converter
    if (disponibilidade.tipo == 'Única') {
      return null;
    }

    try {
      final serie = await criarSerie(
        medicoId: disponibilidade.medicoId,
        dataInicial: disponibilidade.data,
        tipo: disponibilidade.tipo,
        horarios: disponibilidade.horarios,
        unidade: unidade,
      );

      return serie;
    } catch (e) {
      debugPrint('❌ Erro ao converter disponibilidade para série: $e');
      return null;
    }
  }

  /// Cria uma exceção para cancelar uma data específica de uma série
  static Future<void> cancelarDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    Unidade? unidade,
  }) async {
    final excecaoId = 'excecao_${data.millisecondsSinceEpoch}';

    final excecao = ExcecaoSerie(
      id: excecaoId,
      serieId: serieId,
      data: data,
      cancelada: true,
    );

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
    debugPrint(
        '✅ Exceção criada: data ${data.day}/${data.month}/${data.year} cancelada para série $serieId');
  }

  /// Cria uma exceção para modificar horários de uma data específica
  static Future<void> modificarHorariosDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    required List<String> horarios,
    Unidade? unidade,
  }) async {
    final excecaoId = 'excecao_${data.millisecondsSinceEpoch}';

    final excecao = ExcecaoSerie(
      id: excecaoId,
      serieId: serieId,
      data: data,
      cancelada: false,
      horarios: horarios,
    );

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
    debugPrint(
        '✅ Exceção criada: horários modificados para data ${data.day}/${data.month}/${data.year}');
  }

  /// Cria uma exceção para modificar o gabinete de uma data específica de uma série
  static Future<void> modificarGabineteDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    required String novoGabineteId,
    Unidade? unidade,
  }) async {
    // Normalizar a data para garantir correspondência exata
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // Verificar se já existe uma exceção para esta série e data
    // CORREÇÃO: Forçar servidor para garantir que exceções recém-criadas sejam encontradas
    final excecoesExistentes = await SerieService.carregarExcecoes(
      medicoId,
      unidade: unidade,
      dataInicio: dataNormalizada,
      dataFim: dataNormalizada,
      serieId: serieId,
      forcarServidor: true, // Forçar servidor para garantir dados atualizados
    );

    ExcecaoSerie excecao;

    // CORREÇÃO CRÍTICA: Encontrar TODAS as exceções para esta data (não apenas a primeira)
    // Isso evita duplicação quando há múltiplas exceções
    final excecoesParaData = excecoesExistentes
        .where(
          (e) =>
              e.serieId == serieId &&
              e.data.year == dataNormalizada.year &&
              e.data.month == dataNormalizada.month &&
              e.data.day == dataNormalizada.day &&
              !e.cancelada,
        )
        .toList();

    if (excecoesParaData.isNotEmpty) {
      // CORREÇÃO CRÍTICA: Se há múltiplas exceções, cancelar todas exceto a primeira
      // Depois atualizar a primeira com o novo gabinete
      if (excecoesParaData.length > 1) {
        debugPrint(
            '⚠️ [DUPLICAÇÃO] Encontradas ${excecoesParaData.length} exceções para a mesma data! Cancelando duplicatas...');

        // Cancelar todas as exceções exceto a primeira
        for (int i = 1; i < excecoesParaData.length; i++) {
          final excecaoDuplicada = ExcecaoSerie(
            id: excecoesParaData[i].id,
            serieId: excecoesParaData[i].serieId,
            data: excecoesParaData[i].data,
            cancelada: true,
            horarios: excecoesParaData[i].horarios,
            gabineteId: excecoesParaData[i].gabineteId,
          );
          await SerieService.salvarExcecao(excecaoDuplicada, medicoId,
              unidade: unidade);
          debugPrint(
              '🗑️ Exceção duplicada cancelada: ${excecoesParaData[i].id}');
        }
      }

      // Usar a primeira exceção e atualizar com o novo gabinete
      final excecaoExistente = excecoesParaData[0];
      excecao = ExcecaoSerie(
        id: excecaoExistente.id,
        serieId: excecaoExistente.serieId,
        data: excecaoExistente.data,
        cancelada: false, // Garantir que não está cancelada
        horarios:
            excecaoExistente.horarios, // Manter horários existentes se houver
        gabineteId: novoGabineteId, // Atualizar o gabinete
      );
      debugPrint('🔄 Atualizando exceção existente: ${excecao.id}');
    } else {
      // Criar nova exceção
      final excecaoId =
          'excecao_${serieId}_${dataNormalizada.millisecondsSinceEpoch}';
      excecao = ExcecaoSerie(
        id: excecaoId,
        serieId: serieId,
        data: dataNormalizada,
        cancelada: false,
        gabineteId: novoGabineteId,
      );
      debugPrint('➕ Criando nova exceção: ${excecao.id}');
    }

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);

    // CORREÇÃO CRÍTICA: Invalidar cache do dia para garantir que mudanças apareçam imediatamente
    // Isso é especialmente importante quando um administrador faz alterações
    AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    AlocacaoMedicosLogic.invalidateCacheFromDate(
        DateTime(dataNormalizada.year, 1, 1));

    debugPrint(
        '✅ Exceção salva: ID=${excecao.id}, série=$serieId, data=${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}, gabinete=$novoGabineteId');
    debugPrint(
        '   📋 Detalhes: dataKey=${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}, chaveEsperada=${serieId}_${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}');
  }

  /// Aloca uma série inteira a um gabinete
  static Future<void> alocarSerie({
    required String serieId,
    required String medicoId,
    required String gabineteId,
    Unidade? unidade,
  }) async {
    try {
      // Carregar série
      final series =
          await SerieService.carregarSeries(medicoId, unidade: unidade);
      final serie = series.firstWhere((s) => s.id == serieId);

      // Atualizar série com gabinete
      final serieAtualizada = SerieRecorrencia(
        id: serie.id,
        medicoId: serie.medicoId,
        dataInicio: serie.dataInicio,
        dataFim: serie.dataFim,
        tipo: serie.tipo,
        horarios: serie.horarios,
        gabineteId: gabineteId,
        parametros: serie.parametros,
        ativo: serie.ativo,
      );

      await SerieService.salvarSerie(serieAtualizada, unidade: unidade);

      // CORREÇÃO CRÍTICA: Invalidar cache quando uma série é alocada
      // Invalidar cache para todo o ano da série para garantir que todas as alocações geradas sejam atualizadas
      final hoje = DateTime.now();
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(hoje.year, 1, 1));
      // Também invalidar próximos 2 anos caso a série seja infinita
      AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(hoje.year + 1, 1, 1));
      AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(hoje.year + 2, 1, 1));

      debugPrint('✅ Série alocada ao gabinete $gabineteId');
    } catch (e) {
      debugPrint('❌ Erro ao alocar série: $e');
      rethrow;
    }
  }

  /// Desaloca uma série (remove o gabineteId)
  static Future<void> desalocarSerie({
    required String serieId,
    required String medicoId,
    Unidade? unidade,
  }) async {
    try {
      // Carregar série
      final series =
          await SerieService.carregarSeries(medicoId, unidade: unidade);
      final serie = series.firstWhere((s) => s.id == serieId);

      // Atualizar série removendo o gabineteId (definindo como null)
      final serieAtualizada = SerieRecorrencia(
        id: serie.id,
        medicoId: serie.medicoId,
        dataInicio: serie.dataInicio,
        dataFim: serie.dataFim,
        tipo: serie.tipo,
        horarios: serie.horarios,
        gabineteId: null, // Remove a alocação
        parametros: serie.parametros,
        ativo: serie.ativo,
      );

      await SerieService.salvarSerie(serieAtualizada, unidade: unidade);

      // CORREÇÃO CRÍTICA: Invalidar cache quando uma série é desalocada
      // Invalidar cache para todo o ano da série para garantir que todas as alocações geradas sejam atualizadas
      final hoje = DateTime.now();
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(hoje.year, 1, 1));
      // Também invalidar próximos 2 anos caso a série seja infinita
      AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(hoje.year + 1, 1, 1));
      AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(hoje.year + 2, 1, 1));

      debugPrint('✅ Série desalocada (gabinete removido)');
    } catch (e) {
      debugPrint('❌ Erro ao desalocar série: $e');
      rethrow;
    }
  }
}
